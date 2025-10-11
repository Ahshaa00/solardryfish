import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/registration_code.dart';
import '../models/user_role.dart';
import '../services/permission_service.dart';
import '../services/registration_code_service.dart';

class RegistrationCodesPage extends StatefulWidget {
  final String systemId;
  const RegistrationCodesPage({super.key, required this.systemId});

  @override
  State<RegistrationCodesPage> createState() => _RegistrationCodesPageState();
}

class _RegistrationCodesPageState extends State<RegistrationCodesPage> {
  UserRole? userRole;
  List<RegistrationCode> codes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    
    try {
      final role = await PermissionService.getUserRole(widget.systemId);
      final codesList = await RegistrationCodeService.getCodesForSystem(widget.systemId);
      
      if (mounted) {
        setState(() {
          userRole = role;
          codes = codesList;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading codes: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateCode() async {
    if (userRole == null || (userRole != UserRole.owner && userRole != UserRole.admin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Owner and Admin can generate codes'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show expiration dialog
    final days = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text('Code Expiration', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'How many days should this code be valid?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ...[ 1, 3, 7, 14, 30].map((day) => ListTile(
              title: Text(
                '$day day${day > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amber, size: 16),
              onTap: () => Navigator.pop(context, day),
            )),
            ],
          ),
        ),
      ),
    );

    if (days == null) return;

    try {
      final newCode = await RegistrationCodeService.generateCode(
        systemId: widget.systemId,
        expirationDays: days,
      );

      if (mounted) {
        _loadData();
        _showCodeDialog(newCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCodeDialog(RegistrationCode code) {
    final formattedCode = RegistrationCodeService.formatCode(code.code);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Text('Code Generated!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Share this code with the new system owner:',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: SelectableText(
                formattedCode,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Expires: ${DateFormat('MMM dd, yyyy HH:mm').format(code.expiresAt)}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied to clipboard!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
              ),
            ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCode(RegistrationCode code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2235),
        title: const Text('Delete Code?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete code ${RegistrationCodeService.formatCode(code.code)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await RegistrationCodeService.deleteCode(code.id, widget.systemId);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141829),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2235),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Registration Codes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'About Registration Codes',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Generate time-limited codes to securely share system ownership. Each code can only be used once.',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Generate Button
                  if (userRole == UserRole.owner || userRole == UserRole.admin)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _generateCode,
                        icon: const Icon(Icons.add),
                        label: const Text('Generate New Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Codes List
                  if (codes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.qr_code_2, size: 64, color: Colors.grey.shade700),
                            const SizedBox(height: 16),
                            Text(
                              'No registration codes yet',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...codes.map((code) => _buildCodeCard(code)),
                ],
              ),
            ),
    );
  }

  Widget _buildCodeCard(RegistrationCode code) {
    final formattedCode = RegistrationCodeService.formatCode(code.code);
    final isExpired = code.isExpired;
    final isUsed = code.used;
    
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle;
    String statusText = 'Active';
    
    if (isUsed) {
      statusColor = Colors.grey;
      statusIcon = Icons.check;
      statusText = 'Used';
    } else if (isExpired) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Expired';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedCode,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (!isUsed && (userRole == UserRole.owner || userRole == UserRole.admin))
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteCode(code),
                  tooltip: 'Delete code',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade800),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person, 'Generated by', code.generatedByEmail),
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.calendar_today,
            'Created',
            DateFormat('MMM dd, yyyy HH:mm').format(code.createdAt),
          ),
          const SizedBox(height: 4),
          _buildInfoRow(
            Icons.event_busy,
            'Expires',
            DateFormat('MMM dd, yyyy HH:mm').format(code.expiresAt),
          ),
          if (isUsed) ...[
            const SizedBox(height: 4),
            _buildInfoRow(Icons.check, 'Used by', code.usedBy ?? 'Unknown'),
            if (code.usedAt != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.access_time,
                'Used at',
                DateFormat('MMM dd, yyyy HH:mm').format(code.usedAt!),
              ),
            ],
          ],
          if (!isUsed && !isExpired) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: formattedCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied to clipboard!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
