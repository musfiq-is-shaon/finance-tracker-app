import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/loan_contacts_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/glass_card.dart';
import '../../utils/formatters.dart';
import '../../models/loan_activity.dart';

class LoanContactDetailScreen extends ConsumerStatefulWidget {
  final String contactId;
  final String? initialAction; // 'give', 'borrow'

  const LoanContactDetailScreen({
    super.key,
    required this.contactId,
    this.initialAction,
  });

  @override
  ConsumerState<LoanContactDetailScreen> createState() => _LoanContactDetailScreenState();
}

class _LoanContactDetailScreenState extends ConsumerState<LoanContactDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Show add activity dialog on start if action is specified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAction != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showAddActivityDialog(context, widget.initialAction!);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(loanContactDetailsProvider(widget.contactId));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(loanContactDetailsProvider(widget.contactId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final contact = data['contact'];
          final activities = (data['activities'] as List).map((a) => LoanActivity.fromJson(a)).toList();
          return _buildContent(context, contact, activities, isDarkMode);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> contact, List<LoanActivity> activities, bool isDarkMode) {
    final currentBalance = (contact['current_balance'] as num?)?.toDouble() ?? 0;
    final isOwed = currentBalance > 0;
    final isBorrowed = currentBalance < 0;
    final balanceColor = isOwed
        ? AppTheme.loanGivenColor
        : (isBorrowed ? AppTheme.loanBorrowedColor : Colors.grey);

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
            onPressed: () => context.pop(),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditContactDialog(context, contact);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Contact')),
                const PopupMenuItem(value: 'delete', child: Text('Delete Contact')),
              ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    balanceColor.withOpacity(0.3),
                    isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: balanceColor.withOpacity(0.2),
                      child: Text(
                        contact['name'].toString().isNotEmpty 
                            ? contact['name'][0].toString().toUpperCase() 
                            : '?',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: balanceColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      contact['name'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                      ),
                    ),
                    if (contact['phone_number'] != null && contact['phone_number'].toString().isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _callPhone(contact['phone_number']),
                        icon: const Icon(Icons.phone, size: 16),
                        label: Text(contact['phone_number']),
                        style: TextButton.styleFrom(
                          foregroundColor: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Balance Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    isOwed ? 'They Owe You' : (isBorrowed ? 'You Owe' : 'All Settled'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.formatCurrency(currentBalance.abs()),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        'Total Given',
                        contact['total_given'] ?? 0,
                        AppTheme.loanGivenColor,
                        isDarkMode,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3),
                      ),
                      _buildStatItem(
                        'Total Borrowed',
                        contact['total_borrowed'] ?? 0,
                        AppTheme.loanBorrowedColor,
                        isDarkMode,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3),
                      ),
                      _buildStatItem(
                        'Activities',
                        contact['activity_count'] ?? 0,
                        AppTheme.primaryColor,
                        isDarkMode,
                        isCount: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Quick Action Buttons
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Give Loan',
                    Icons.arrow_forward,
                    AppTheme.loanGivenColor,
                    () => _showAddActivityDialog(context, 'give'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Borrow Money',
                    Icons.arrow_back,
                    AppTheme.loanBorrowedColor,
                    () => _showAddActivityDialog(context, 'borrow'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Activities Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Activity History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
              ),
            ),
          ),
        ),

        // Activities List
        activities.isEmpty
            ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No activities yet',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildActivityItem(activities[index], isDarkMode);
                  },
                  childCount: activities.length,
                ),
              ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, num value, Color color, bool isDarkMode, {bool isCount = false}) {
    return Column(
      children: [
        Text(
          isCount ? value.toString() : Formatters.formatCurrency(value.toDouble()),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : AppTheme.lightSubTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(LoanActivity activity, bool isDarkMode) {
    final isPositive = activity.activityType == LoanActivityType.given ||
        activity.activityType == LoanActivityType.paymentReceived;
    final color = isPositive
        ? AppTheme.loanGivenColor
        : AppTheme.loanBorrowedColor;

    IconData icon;
    String actionText;
    
    switch (activity.activityType) {
      case LoanActivityType.given:
        icon = Icons.arrow_forward;
        actionText = 'Loan Given';
        break;
      case LoanActivityType.borrowed:
        icon = Icons.arrow_back;
        actionText = 'Loan Taken';
        break;
      case LoanActivityType.paymentReceived:
        icon = Icons.arrow_downward;
        actionText = 'Payment Received';
        break;
      case LoanActivityType.paymentMade:
        icon = Icons.arrow_upward;
        actionText = 'Payment Made';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onLongPress: () => _showDeleteActivityDialog(context, activity),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.formatDate(activity.activityDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    if (activity.description != null && activity.description!.isNotEmpty)
                      Text(
                        activity.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPositive ? '+' : '-'} ${Formatters.formatCurrency(activity.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Balance: ${Formatters.formatCurrency(activity.balanceAfter.abs())}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isDarkMode ? Colors.white54 : Colors.grey,
                  size: 20,
                ),
                onPressed: () => _showDeleteActivityDialog(context, activity),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteActivityDialog(BuildContext context, LoanActivity activity) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String actionText;
    switch (activity.activityType) {
      case LoanActivityType.given:
        actionText = 'Loan Given';
        break;
      case LoanActivityType.borrowed:
        actionText = 'Loan Taken';
        break;
      case LoanActivityType.paymentReceived:
        actionText = 'Payment Received';
        break;
      case LoanActivityType.paymentMade:
        actionText = 'Payment Made';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
        title: Text(
          'Delete Activity?',
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
        ),
        content: Text(
          'This will delete the "$actionText" of ${Formatters.formatCurrency(activity.amount)}. The balance will be recalculated for all remaining activities. This action cannot be undone.',
          style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(loanActivityProvider.notifier).deleteActivity(
                  widget.contactId,
                  activity.id,
                );
                // Invalidate providers to ensure fresh data
                ref.invalidate(loanContactDetailsProvider(widget.contactId));
                ref.invalidate(loanContactsProvider);
                // Force reload contacts
                ref.read(loanContactsProvider.notifier).loadContacts();
                ref.read(dashboardProvider.notifier).refresh();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Activity deleted successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddActivityDialog(BuildContext context, String actionType) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime selectedDate = DateTime.now();
    double availableBalance = 0;
    bool isLoadingBalance = true;

    String activityType;
    String title;
    Color color;

    switch (actionType) {
      case 'give':
        activityType = 'given';
        title = 'Give Loan';
        color = AppTheme.loanGivenColor;
        break;
      case 'borrow':
        activityType = 'borrowed';
        title = 'Borrow Money';
        color = AppTheme.loanBorrowedColor;
        break;
      default:
        return;
    }

    // Fetch available balance for validation
    ref.read(balanceProvider).whenData((balance) {
      availableBalance = balance;
      isLoadingBalance = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            // Watch for balance changes
            final balanceAsync = ref.watch(balanceProvider);
            balanceAsync.whenData((balance) {
              availableBalance = balance;
              isLoadingBalance = false;
            });
            
            return Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            actionType == 'give' ? Icons.arrow_forward : Icons.arrow_back,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Show available balance for 'give' action
                    if (actionType == 'give') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Available Balance: ',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                              ),
                            ),
                            if (isLoadingBalance)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Text(
                                Formatters.formatCurrency(availableBalance),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: availableBalance > 0 ? AppTheme.successColor : AppTheme.errorColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        prefixStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white24 : Colors.grey.withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Enter valid amount';
                        }
                        // Check balance for 'give' action
                        if (actionType == 'give' && amount > availableBalance) {
                          return 'Insufficient balance';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(
                        'Date',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        Formatters.formatDate(selectedDate),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setModalState(() => selectedDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 2,
                      style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                      decoration: InputDecoration(
                        hintText: 'Add note (optional)',
                        hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              await ref.read(loanActivityProvider.notifier).addActivity(
                                contactId: widget.contactId,
                                activityType: activityType,
                                amount: double.parse(amountController.text),
                                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                                activityDate: selectedDate,
                              );
                              // Refresh data
                              ref.invalidate(loanContactDetailsProvider(widget.contactId));
                              ref.invalidate(loanContactsProvider);
                              // Force reload contacts
                              ref.read(loanContactsProvider.notifier).loadContacts();
                              ref.read(dashboardProvider.notifier).refresh();
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$title successfully'),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Save $title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditContactDialog(BuildContext context, Map<String, dynamic> contact) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: contact['name']);
    final phoneController = TextEditingController(text: contact['phone_number'] ?? '');
    final notesController = TextEditingController(text: contact['notes'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Contact',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameController,
                style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            await ref.read(loanContactsProvider.notifier).updateContact(
                              widget.contactId,
                              {
                                'name': nameController.text,
                                'phone_number': phoneController.text.isNotEmpty ? phoneController.text : null,
                                'notes': notesController.text.isNotEmpty ? notesController.text : null,
                              },
                            );
                            ref.invalidate(loanContactDetailsProvider(widget.contactId));
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
        title: Text(
          'Delete Contact?',
          style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
        ),
        content: Text(
          'This will delete all loan activities with this person. This action cannot be undone.',
          style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(loanContactsProvider.notifier).deleteContact(widget.contactId);
                ref.read(dashboardProvider.notifier).refresh();
                if (context.mounted) {
                  Navigator.pop(context);
                  context.pop();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

