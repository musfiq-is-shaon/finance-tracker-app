-- =====================================================
-- PERSON-CENTRIC LOAN SYSTEM UPDATE
-- =====================================================

-- =====================================================
-- LOAN CONTACTS TABLE (New)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.loan_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone_number TEXT,
    email TEXT,
    initial_balance DECIMAL(15, 2) DEFAULT 0, -- positive = they owe you, negative = you owe them
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- LOAN ACTIVITIES TABLE (Replaces individual loans)
-- =====================================================
CREATE TABLE IF NOT EXISTS public.loan_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES public.loan_contacts(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('given', 'borrowed', 'payment_received', 'payment_made')),
    amount DECIMAL(15, 2) NOT NULL,
    balance_after DECIMAL(15, 2) NOT NULL, -- running balance after this activity
    description TEXT,
    activity_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- ADD CONTACT_ID TO EXISTING LOANS (for migration)
-- =====================================================
ALTER TABLE public.loans ADD COLUMN IF NOT EXISTS contact_id UUID REFERENCES public.loan_contacts(id) ON DELETE SET NULL;

-- =====================================================
-- INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_loan_contacts_user_id ON public.loan_contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_loan_activities_user_id ON public.loan_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_loan_activities_contact_id ON public.loan_activities(contact_id);
CREATE INDEX IF NOT EXISTS idx_loan_activities_date ON public.loan_activities(activity_date);

-- =====================================================
-- RLS POLICIES FOR LOAN CONTACTS
-- =====================================================
ALTER TABLE public.loan_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own loan contacts" ON public.loan_contacts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own loan contacts" ON public.loan_contacts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own loan contacts" ON public.loan_contacts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own loan contacts" ON public.loan_contacts
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- RLS POLICIES FOR LOAN ACTIVITIES
-- =====================================================
ALTER TABLE public.loan_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own loan activities" ON public.loan_activities
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own loan activities" ON public.loan_activities
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own loan activities" ON public.loan_activities
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own loan activities" ON public.loan_activities
    FOR DELETE USING (auth.uid() = user_id);

-- =====================================================
-- VIEW: LOAN CONTACT WITH BALANCE
-- =====================================================
CREATE OR REPLACE VIEW public.loan_contacts_with_balance AS
SELECT 
    lc.*,
    COALESCE(
        (SELECT la.balance_after 
         FROM public.loan_activities la 
         WHERE la.contact_id = lc.id 
         ORDER BY la.created_at DESC 
         LIMIT 1
        ), 0
    ) AS current_balance,
    (SELECT COUNT(*) FROM public.loan_activities WHERE contact_id = lc.id) AS activity_count
FROM public.loan_contacts lc;

-- =====================================================
-- FUNCTION: ADD LOAN ACTIVITY (Core Business Logic)
-- =====================================================
CREATE OR REPLACE FUNCTION public.add_loan_activity(
    p_user_id UUID,
    p_contact_id UUID,
    p_activity_type TEXT,
    p_amount DECIMAL(15, 2),
    p_description TEXT DEFAULT NULL,
    p_activity_date DATE DEFAULT CURRENT_DATE
)
RETURNS UUID AS $$
DECLARE
    v_previous_balance DECIMAL(15, 2);
    v_new_balance DECIMAL(15, 2);
    v_activity_id UUID;
BEGIN
    -- Get previous balance
    SELECT COALESCE(
        (SELECT balance_after 
         FROM public.loan_activities 
         WHERE contact_id = p_contact_id 
         ORDER BY created_at DESC 
         LIMIT 1
        ), 0
    ) INTO v_previous_balance;
    
    -- Calculate new balance based on activity type
    -- given: you gave money, they owe you more (balance increases)
    -- borrowed: you borrowed money, you owe them more (balance decreases)
    -- payment_received: they paid you, they owe you less (balance decreases)
    -- payment_made: you paid them, you owe them less (balance increases)
    CASE p_activity_type
        WHEN 'given' THEN
            v_new_balance := v_previous_balance + p_amount;
        WHEN 'borrowed' THEN
            v_new_balance := v_previous_balance - p_amount;
        WHEN 'payment_received' THEN
            v_new_balance := v_previous_balance - p_amount;
        WHEN 'payment_made' THEN
            v_new_balance := v_previous_balance + p_amount;
        ELSE
            RAISE EXCEPTION 'Invalid activity type: %', p_activity_type;
    END CASE;
    
    -- Insert activity
    INSERT INTO public.loan_activities (
        user_id,
        contact_id,
        activity_type,
        amount,
        balance_after,
        description,
        activity_date
    ) VALUES (
        p_user_id,
        p_contact_id,
        p_activity_type,
        p_amount,
        v_new_balance,
        p_description,
        p_activity_date
    )
    RETURNING id INTO v_activity_id;
    
    -- Update contact's updated_at
    UPDATE public.loan_contacts 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = p_contact_id;
    
    RETURN v_activity_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FUNCTION: GET LOAN CONTACT DETAILS
-- =====================================================
CREATE OR REPLACE FUNCTION public.get_loan_contact_details(p_contact_id UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    phone_number TEXT,
    current_balance DECIMAL(15, 2),
    total_given DECIMAL(15, 2),
    total_borrowed DECIMAL(15, 2),
    total_paid_to_you DECIMAL(15, 2),
    total_you_paid DECIMAL(15, 2),
    activity_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        lc.id,
        lc.name,
        lc.phone_number,
        COALESCE(
            (SELECT la.balance_after 
             FROM public.loan_activities la 
             WHERE la.contact_id = lc.id 
             ORDER BY la.created_at DESC 
             LIMIT 1), 0
        ) AS current_balance,
        COALESCE(
            (SELECT SUM(amount) FROM public.loan_activities 
             WHERE contact_id = p_contact_id AND activity_type = 'given'), 0
        )::DECIMAL(15, 2) AS total_given,
        COALESCE(
            (SELECT SUM(amount) FROM public.loan_activities 
             WHERE contact_id = p_contact_id AND activity_type = 'borrowed'), 0
        )::DECIMAL(15, 2) AS total_borrowed,
        COALESCE(
            (SELECT SUM(amount) FROM public.loan_activities 
             WHERE contact_id = p_contact_id AND activity_type = 'payment_received'), 0
        )::DECIMAL(15, 2) AS total_paid_to_you,
        COALESCE(
            (SELECT SUM(amount) FROM public.loan_activities 
             WHERE contact_id = p_contact_id AND activity_type = 'payment_made'), 0
        )::DECIMAL(15, 2) AS total_you_paid,
        (SELECT COUNT(*) FROM public.loan_activities WHERE contact_id = p_contact_id)::INT AS activity_count
    FROM public.loan_contacts lc
    WHERE lc.id = p_contact_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

