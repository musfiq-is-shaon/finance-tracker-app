import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_theme.dart';
import '../../models/loan_contact.dart';
import '../../providers/loan_contacts_provider.dart';
import '../../widgets/glass_card.dart';
import '../../utils/formatters.dart';

class LoanContactsScreen extends ConsumerStatefulWidget {
  const LoanContactsScreen({super.key});

  @override
  ConsumerState<LoanContactsScreen> createState() => _LoanContactsScreenState();
}

class _LoanContactsScreenState extends ConsumerState<LoanContactsScreen> with WidgetsBindingObserver {
  String _searchQuery = '';
  bool _showOwedOnly = false;
  bool _showBorrowedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Force reload contacts when screen is opened
      _loadContacts();
    });
  }

  Future<void> _loadContacts() async {
    await ref.read(loanContactsProvider.notifier).loadContacts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh contacts when screen is resumed
      _loadContacts();
    }
  }

  Future<void> _refreshContacts() async {
    await ref.read(loanContactsProvider.notifier).loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(loanContactsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Watch for changes - if data is empty, trigger reload
    ref.listen<AsyncValue<List<LoanContact>>>(loanContactsProvider, (previous, next) {
      next.whenData((contacts) {
        if (contacts.isEmpty && previous?.hasValue == true) {
          // Data was cleared, reload
          _loadContacts();
        }
      });
    });

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.lightBackgroundColor,
      appBar: AppBar(
        title: Text('Loan Contacts', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(loanContactsProvider.notifier).loadContacts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (contacts) {
          // Filter contacts
          var filteredContacts = contacts.where((c) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              if (!c.name.toLowerCase().contains(query) &&
                  !(c.phoneNumber?.toLowerCase().contains(query) ?? false)) {
                return false;
              }
            }
            // Balance filter
            if (_showOwedOnly && c.currentBalance <= 0) return false;
            if (_showBorrowedOnly && c.currentBalance >= 0) return false;
            return true;
          }).toList();

          if (filteredContacts.isEmpty) {
            return _buildEmptyState(context, isDarkMode);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(loanContactsProvider.notifier).loadContacts();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                return _buildContactCard(filteredContacts[index], isDarkMode);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactDialog(context),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _showOwedOnly || _showBorrowedOnly
                ? 'No contacts found'
                : 'No loan contacts yet',
            style: TextStyle(
              color: isDarkMode ? Colors.white.withOpacity(0.7) : AppTheme.lightSubTextColor,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first loan contact',
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(contact, bool isDarkMode) {
    final isOwed = contact.currentBalance > 0;
    final isBorrowed = contact.currentBalance < 0;
    final color = isOwed
        ? AppTheme.loanGivenColor
        : (isBorrowed ? AppTheme.loanBorrowedColor : Colors.grey);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => context.push('/loan-contact/${contact.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.2),
                  child: Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (contact.phoneNumber != null && contact.phoneNumber!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: isDarkMode ? Colors.white54 : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              contact.phoneNumber!,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      Text(
                        '${contact.activityCount} activities',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(contact.currentBalance.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOwed
                            ? 'Owes You'
                            : (isBorrowed ? 'You Owe' : 'Settled'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/loan-contact/${contact.id}', extra: 'give'),
                    icon: Icon(Icons.arrow_forward, size: 16, color: AppTheme.loanGivenColor),
                    label: Text('Give', style: TextStyle(color: AppTheme.loanGivenColor, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.loanGivenColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/loan-contact/${contact.id}', extra: 'borrow'),
                    icon: Icon(Icons.arrow_back, size: 16, color: AppTheme.loanBorrowedColor),
                    label: Text('Borrow', style: TextStyle(color: AppTheme.loanBorrowedColor, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.loanBorrowedColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter & Search',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  setModalState(() => _searchQuery = value);
                },
                style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                decoration: InputDecoration(
                  hintText: 'Search by name or phone',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.grey),
                  prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.white54 : Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Balance Filter',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Owes Me'),
                    selected: _showOwedOnly,
                    onSelected: (selected) {
                      setModalState(() {
                        _showOwedOnly = selected;
                        if (selected) _showBorrowedOnly = false;
                      });
                      setState(() {});
                    },
                    selectedColor: AppTheme.loanGivenColor.withOpacity(0.3),
                  ),
                  FilterChip(
                    label: const Text('I Owe'),
                    selected: _showBorrowedOnly,
                    onSelected: (selected) {
                      setModalState(() {
                        _showBorrowedOnly = selected;
                        if (selected) _showOwedOnly = false;
                      });
                      setState(() {});
                    },
                    selectedColor: AppTheme.loanBorrowedColor.withOpacity(0.3),
                  ),
                  FilterChip(
                    label: const Text('All'),
                    selected: !_showOwedOnly && !_showBorrowedOnly,
                    onSelected: (selected) {
                      setModalState(() {
                        _showOwedOnly = false;
                        _showBorrowedOnly = false;
                      });
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Show permission denied dialog
    void showPermissionDeniedDialog() {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDarkMode ? AppTheme.darkCardColor : AppTheme.lightCardColor,
          title: Text('Permission Required', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
          content: Text(
            'Contact permission is required to pick contacts. Please enable it in app settings.',
            style: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    // Function to pick contact from phone
    Future<void> pickContact() async {
      var status = await Permission.contacts.status;
      
      if (status.isDenied) {
        status = await Permission.contacts.request();
      }
      
      if (status.isGranted) {
        try {
          final contact = await FlutterContacts.openExternalPick();
          if (contact != null) {
            final fullContact = await FlutterContacts.getContact(contact.id, withProperties: true);
            if (fullContact != null) {
              setState(() {
                nameController.text = fullContact.displayName;
                if (fullContact.phones.isNotEmpty) {
                  phoneController.text = fullContact.phones.first.number;
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
        showPermissionDeniedDialog();
      }
    }

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
          builder: (context, setModalState) => Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add New Contact',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : AppTheme.lightTextColor,
                        ),
                      ),
                      // Pick from contacts button
                      TextButton.icon(
                        onPressed: pickContact,
                        icon: const Icon(Icons.contacts, size: 20),
                        label: const Text('Pick Contact'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a new loan relationship',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
                      prefixIcon: Icon(Icons.person, color: isDarkMode ? Colors.white54 : Colors.grey),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: isDarkMode ? Colors.white : AppTheme.lightTextColor),
                    decoration: InputDecoration(
                      labelText: 'Phone (Optional)',
                      labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : AppTheme.lightSubTextColor),
                      prefixIcon: Icon(Icons.phone, color: isDarkMode ? Colors.white54 : Colors.grey),
                    ),
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
                                final contact = await ref.read(loanContactsProvider.notifier).createContact(
                                  name: nameController.text,
                                  phoneNumber: phoneController.text.isNotEmpty ? phoneController.text : null,
                                );
                                if (contact != null && context.mounted) {
                                  Navigator.pop(context);
                                  // Navigate to add first activity
                                  context.push('/loan-contact/${contact.id}');
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                          ),
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

