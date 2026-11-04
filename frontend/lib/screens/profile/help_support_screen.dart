import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency Helpline Banner
          Card(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk, color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency Water Hotline',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For burst mains or hazardous contamination call 1939',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // FAQ Section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                _buildFaqTile(
                  'How does incident reporting work?',
                  'Take a photo of the sanitation or water issue, confirm your GPS coordinates, and add a brief description. You can accept AI classification or manually choose category and severity.',
                ),
                const Divider(height: 1),
                _buildFaqTile(
                  'How does Gemini AI analyze my photos?',
                  'Gemini processes the uploaded image to suggest appropriate category and urgency tiers. AI output is purely advisory: you can always override it or submit directly with AI bypassed.',
                ),
                const Divider(height: 1),
                _buildFaqTile(
                  'Can I report issues when offline?',
                  'Yes! If network connectivity is lost, your report and photo are saved securely in your offline queue. The app will automatically sync it once your connection is restored.',
                ),
                const Divider(height: 1),
                _buildFaqTile(
                  'What do status colors mean?',
                  '• Pending (Orange): Awaiting municipal inspection\n• In Progress (Blue): Repair crew dispatched\n• Resolved (Green): Fix completed and verified\n• Rejected (Red): Duplicate or non-infrastructure report',
                ),
                const Divider(height: 1),
                _buildFaqTile(
                  'How do officials track resolution history?',
                  'Every update by municipal staff creates an immutable audit record visible on the incident detail timeline, including timestamp, official identity, and repair notes.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Feedback & Support Contact
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'CONTACT & FEEDBACK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Color(0xFF38BDF8)),
                  title: const Text('Email Support'),
                  subtitle: const Text('support@aquafix.org'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support email: support@aquafix.org')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined, color: Color(0xFFF59E0B)),
                  title: const Text('Send App Feedback'),
                  subtitle: const Text('Suggest improvements or report an issue'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showFeedbackDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your thoughts help improve AquaFix municipal sanitation reporting for everyone.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your suggestions or feedback...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you! Your feedback has been submitted to the AquaFix team.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
