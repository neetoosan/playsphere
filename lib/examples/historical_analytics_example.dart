import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/historical_analytics_service.dart';
import '../constants.dart';

/// Example screen showing how to use HistoricalAnalyticsService
/// to display lifetime analytics that preserve deleted video data
class HistoricalAnalyticsExample extends StatefulWidget {
  final String creatorId;
  
  const HistoricalAnalyticsExample({super.key, required this.creatorId});

  @override
  State<HistoricalAnalyticsExample> createState() => _HistoricalAnalyticsExampleState();
}

class _HistoricalAnalyticsExampleState extends State<HistoricalAnalyticsExample> {
  final HistoricalAnalyticsService _analyticsService = Get.find<HistoricalAnalyticsService>();
  Map<String, dynamic> _lifetimeAnalytics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      final analytics = await _analyticsService.getLifetimeAnalytics(widget.creatorId);
      setState(() {
        _lifetimeAnalytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Creator Analytics'),
        backgroundColor: Colors.black,
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lifetime Totals Section
                  _buildSectionCard(
                    title: 'Lifetime Analytics',
                    subtitle: 'Complete history including deleted videos',
                    icon: Icons.analytics,
                    color: Colors.green,
                    children: [
                      _buildStatRow('Total Videos Created', _lifetimeAnalytics['lifetime']?['videos'] ?? 0),
                      _buildStatRow('Total Views', _lifetimeAnalytics['lifetime']?['views'] ?? 0),
                      _buildStatRow('Total Likes', _lifetimeAnalytics['lifetime']?['likes'] ?? 0),
                      _buildStatRow('Total Comments', _lifetimeAnalytics['lifetime']?['comments'] ?? 0),
                      _buildStatRow('Total Shares', _lifetimeAnalytics['lifetime']?['shares'] ?? 0),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Current Active Videos Section
                  _buildSectionCard(
                    title: 'Active Videos',
                    subtitle: 'Currently visible on the platform',
                    icon: Icons.visibility,
                    color: Colors.blue,
                    children: [
                      _buildStatRow('Active Videos', _lifetimeAnalytics['currentActive']?['videos'] ?? 0),
                      _buildStatRow('Active Views', _lifetimeAnalytics['currentActive']?['views'] ?? 0),
                      _buildStatRow('Active Likes', _lifetimeAnalytics['currentActive']?['likes'] ?? 0),
                      _buildStatRow('Active Comments', _lifetimeAnalytics['currentActive']?['comments'] ?? 0),
                      _buildStatRow('Active Shares', _lifetimeAnalytics['currentActive']?['shares'] ?? 0),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Historical (Deleted) Videos Section
                  if ((_lifetimeAnalytics['historical']?['videos'] ?? 0) > 0) ...[
                    _buildSectionCard(
                      title: 'Deleted Videos History',
                      subtitle: 'Analytics preserved from deleted content',
                      icon: Icons.history,
                      color: Colors.orange,
                      children: [
                        _buildStatRow('Deleted Videos', _lifetimeAnalytics['historical']?['videos'] ?? 0),
                        _buildStatRow('Historical Views', _lifetimeAnalytics['historical']?['views'] ?? 0),
                        _buildStatRow('Historical Likes', _lifetimeAnalytics['historical']?['likes'] ?? 0),
                        _buildStatRow('Historical Comments', _lifetimeAnalytics['historical']?['comments'] ?? 0),
                        _buildStatRow('Historical Shares', _lifetimeAnalytics['historical']?['shares'] ?? 0),
                      ],
                    ),
                    SizedBox(height: 16),
                  ],
                  
                  // Earnings Section
                  _buildSectionCard(
                    title: 'Earnings & Monetization',
                    subtitle: 'Revenue preserved including deleted videos',
                    icon: Icons.monetization_on,
                    color: Colors.purple,
                    children: [
                      _buildEarningsRow('Total Earning Views', _lifetimeAnalytics['earnings']?['totalEarningViews'] ?? 0),
                      _buildEarningsRow('Total Earnings', '₦${(_lifetimeAnalytics['earnings']?['totalEarnings'] ?? 0.0).toStringAsFixed(2)}'),
                      _buildEarningsRow('Unpaid Earnings', '₦${(_lifetimeAnalytics['earnings']?['unpaidEarnings'] ?? 0.0).toStringAsFixed(2)}'),
                      _buildEarningsRow('Paid Views', _lifetimeAnalytics['earnings']?['totalPaidViews'] ?? 0),
                      _buildEarningsRow('Avg. Per View', '₦${(_lifetimeAnalytics['earnings']?['averageEarningsPerView'] ?? 0.0).toStringAsFixed(2)}'),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Detailed Earnings Breakdown Button
                  ElevatedButton.icon(
                    onPressed: _showEarningsBreakdown,
                    icon: Icon(Icons.account_balance),
                    label: Text('View Detailed Earnings Breakdown'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Info Card
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Analytics Protection',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your lifetime analytics include all videos you\'ve ever created, even those that have been deleted. '
                          'This ensures your complete content history and earnings are always preserved.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white70),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white70),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: Colors.green[300],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEarningsBreakdown() async {
    try {
      final breakdown = await _analyticsService.getEarningsBreakdown(widget.creatorId);
      
      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Row(
            children: [
              Icon(Icons.account_balance, color: Colors.green),
              SizedBox(width: 8),
              Text('Earnings Breakdown', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBreakdownSection('Active Videos', breakdown['active']),
                SizedBox(height: 16),
                if ((breakdown['deleted']?['videosCount'] ?? 0) > 0) ...[
                  _buildBreakdownSection('Deleted Videos', breakdown['deleted']),
                  SizedBox(height: 16),
                ],
                _buildBreakdownSection('Total Stored', breakdown['totals']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to load earnings breakdown: $e');
    }
  }

  Widget _buildBreakdownSection(String title, Map<String, dynamic>? data) {
    if (data == null) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ...data.entries.map((entry) => Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatFieldName(entry.key),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  entry.value.toString(),
                  style: TextStyle(color: Colors.green[300], fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _formatFieldName(String fieldName) {
    // Convert camelCase to readable format
    String result = fieldName.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (Match match) => ' ${match.group(0)}',
    );
    return result.substring(0, 1).toUpperCase() + result.substring(1);
  }
}
