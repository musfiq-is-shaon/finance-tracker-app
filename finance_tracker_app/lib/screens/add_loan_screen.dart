import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme/app_theme.dart';
import '../providers/loan_contacts_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/glass_card.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  final String? loanType;

  const AddLoanScreen({super.key, this.loanType});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  late String _type;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  double _currentBalance = 0.0;
  bool _isCreatingNewContact = true; // Toggle between new contact or existing

  @override
  void initState() {
    super.initState();
    _type = widget.loanType ?? 'given';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickContact() async {
    var status = await Permission.contacts.status;
    
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    
    if (status.isGranted) {
      try {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          final fullContact = await FlutterContacts.getContact(contact.id, withProperties: true);
          if (fullContact != null && mounted) {
            setState(() {
              _nameController.text = fullContact.displayName;
              if (fullContact.phones.isNotEmpty) {
                _phoneController.text = fullContact.phones.first.number;
              }
            });
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error picking contact: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else {
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    if (mounted) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
          title: Text('Permission Required', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          content: Text(
            'Contact permission is required to pick contacts. Please enable it in app settings.',
            style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;

    // For 'given' loans, check balance
    if (_type == 'given') {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount > _currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient balance! You have ৳${_currentBalance.toStringAsFixed(2)}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final activityType = _type == 'given' ? 'given' : 'borrowed';
      
      if (_isCreatingNewContact) {
        // Create new contact with first activity
        final contact = await ref.read(loanContactsProvider.notifier).createContact(
          name: _nameController.text,
          phoneNumber: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        );
        
        if (contact != null) {
          // Add first activity
          await ref.read(loanActivityProvider.notifier).addActivity(
            contactId: contact.id,
            activityType: activityType,
            amount: double.parse(_amountController.text),
            description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
            activityDate: _selectedDate,
          );
        }
      } else {
        // Use existing contact - navigate to contact detail to add activity
        // Show contact picker first
        if (mounted) {
          _showContactPicker(activityType);
        }
        setState(() => _isLoading = false);
        return;
      }
      
      ref.invalidate(dashboardProvider);
      ref.read(dashboardProvider.notifier).refresh();
      ref.invalidate(loanContactsProvider);
      await ref.read(loanContactsProvider.notifier).loadContacts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan added successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error: $e';
        if (e.toString().contains('Insufficient balance')) {
          errorMessage = 'Insufficient balance! You have ৳${_currentBalance.toStringAsFixed(2)}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showContactPicker(String activityType) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final contactsAsync = ref.read(loanContactsProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Contact',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                ),
              ),
            ),
            Expanded(
              child: contactsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (contacts) {
                  if (contacts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'No contacts yet',
                            style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                          child: Text(
                            contact.name[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                        ),
                        subtitle: Text(
                          'Balance: ৳${contact.currentBalance.abs().toStringAsFixed(2)} ${contact.currentBalance > 0 ? "(They owe you)" : (contact.currentBalance < 0 ? "(You owe)" : "(Settled)")}',
                          style: TextStyle(
                            color: contact.currentBalance > 0 
                                ? AppTheme.loanGivenColor 
                                : (contact.currentBalance < 0 ? AppTheme.loanBorrowedColor : Colors.grey),
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await ref.read(loanActivityProvider.notifier).addActivity(
                            contactId: contact.id,
                            activityType: activityType,
                            amount: double.parse(_amountController.text),
                            description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                            activityDate: _selectedDate,
                          );
                          ref.invalidate(dashboardProvider);
                          ref.read(dashboardProvider.notifier).refresh();
                          ref.invalidate(loanContactsProvider);
                          ref.invalidate(loanContactDetailsProvider(contact.id));
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loan added successfully'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                            context.pop();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final balanceAsync = ref.watch(balanceProvider);

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Add ${_type == 'given' ? 'Loan Given' : 'Loan Borrowed'}',
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Balance Display
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                          ),
                        ),
                        balanceAsync.when(
                          data: (balance) {
                            _currentBalance = balance;
                            return Text(
                              '৳${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                              ),
                            );
                          },
                          loading: () => const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                          ),
                          error: (_, __) => Text(
                            '৳${_currentBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Loan Type Selection
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loan Type',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTypeButton('given', 'Loan Given', AppTheme.loanGivenColor, isDarkMode),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTypeButton('borrowed', 'Loan Borrowed', AppTheme.loanBorrowedColor, isDarkMode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Contact Selection Toggle
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildContactToggle(true, 'New Contact', isDarkMode),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildContactToggle(false, 'Existing Contact', isDarkMode),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Person Name
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Person Name',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                          ),
                        ),
                        if (_isCreatingNewContact)
                          TextButton.icon(
                            onPressed: _pickContact,
                            icon: const Icon(Icons.contacts, size: 18),
                            label: const Text('Pick Contact'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      enabled: _isCreatingNewContact,
                      style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                      decoration: InputDecoration(
                        hintText: 'Enter name',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                        prefixIcon: Icon(Icons.person, color: isDarkMode ? Colors.white54 : Colors.grey),
                      ),
                      validator: (value) {
                        if (!_isCreatingNewContact) return null;
                        if (value == null || value.isEmpty) {
                          return 'Please enter the person name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Phone Number
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone Number (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      enabled: _isCreatingNewContact,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                      decoration: InputDecoration(
                        hintText: 'Enter phone number',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                        prefixIcon: Icon(Icons.phone, color: isDarkMode ? Colors.white54 : Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Amount
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                      ),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: _type == 'given' ? AppTheme.loanGivenColor : AppTheme.loanBorrowedColor,
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        if (_type == 'given' && amount > _currentBalance) {
                          return 'Insufficient balance';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Date
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      ),
                      title: Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white54 : Colors.grey),
                      onTap: _selectDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                      decoration: InputDecoration(
                        hintText: 'Add a note...',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveLoan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _type == 'given' ? AppTheme.loanGivenColor : AppTheme.loanBorrowedColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save ${_type == 'given' ? 'Loan Given' : 'Loan Borrowed'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, Color color, bool isDarkMode) {
    final isSelected = _type == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _type = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3)),
            width: 2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildContactToggle(bool isNew, String label, bool isDarkMode) {
    final isSelected = _isCreatingNewContact == isNew;
    final color = AppTheme.primaryColor;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isCreatingNewContact = isNew;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3)),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNew ? Icons.person_add : Icons.people,
              size: 18,
              color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

