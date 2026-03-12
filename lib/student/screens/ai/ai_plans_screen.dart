import 'package:flutter/material.dart';
import 'package:catuc_portal/theme/app_colors.dart';
import 'package:catuc_portal/student/services/student_api_service.dart';

class AiPlansScreen extends StatefulWidget {
  final String studentId;
  final String? currentPlanName;

  const AiPlansScreen({super.key, required this.studentId, this.currentPlanName});

  @override
  State<AiPlansScreen> createState() => _AiPlansScreenState();
}

class _AiPlansScreenState extends State<AiPlansScreen> {
  late Future<List<Map<String, dynamic>>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = const StudentApiService().fetchAiPlans();
  }

  IconData _planIcon(String name) {
    switch (name.toLowerCase()) {
      case 'free':
        return Icons.card_giftcard_rounded;
      case 'starter':
        return Icons.rocket_launch_rounded;
      case 'standard':
        return Icons.star_rounded;
      case 'premium':
        return Icons.diamond_rounded;
      case 'unlimited':
        return Icons.all_inclusive_rounded;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _planColor(String name) {
    switch (name.toLowerCase()) {
      case 'free':
        return Colors.grey;
      case 'starter':
        return Colors.blue;
      case 'standard':
        return Colors.orange;
      case 'premium':
        return Colors.purple;
      case 'unlimited':
        return Colors.amber;
      default:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('AI Plans', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final plans = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.blueGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Choose Your AI Plan',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unlock more AI messages per day by upgrading your plan.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...plans.map((plan) {
                  final name = plan['name'] as String? ?? '';
                  final price = plan['price'] is int ? plan['price'] as int : int.tryParse(plan['price'].toString()) ?? 0;
                  final dailyLimit = plan['daily_limit'] is int ? plan['daily_limit'] as int : int.tryParse(plan['daily_limit'].toString()) ?? 0;
                  final description = plan['description'] as String? ?? '';
                  final isCurrent = widget.currentPlanName?.toLowerCase() == name.toLowerCase();
                  final isUnlimited = dailyLimit < 0;
                  final color = _planColor(name);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: isCurrent ? Border.all(color: color, width: 2) : null,
                        boxShadow: isDark
                            ? []
                            : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_planIcon(name), color: color, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('CURRENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isUnlimited ? 'Unlimited messages/day' : '$dailyLimit messages/day',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                price == 0 ? 'FREE' : '${price}F/mo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          if (!isCurrent && price > 0) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Contact admin to subscribe to $name plan.')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: color,
                                  side: BorderSide(color: color),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text('Upgrade to $name'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppColors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'To upgrade, contact the admin or visit the payment portal. Plans are billed monthly.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
