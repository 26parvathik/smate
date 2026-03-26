import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          'Sign in to view analytics.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load analytics.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final trips = snapshot.data!.docs
            .map((doc) => TripAnalytics.fromMap(doc.data() as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (trips.isEmpty) {
          return const _EmptyAnalyticsState();
        }

        final summary = AnalyticsSummary.fromTrips(trips);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.header,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Safety Score Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _MetricCard(
                  title: 'Average Weekly Score',
                  value: '${summary.averageScore.round()} / 100',
                ),
                _MetricCard(
                  title: 'Hard Braking Trend',
                  value: summary.harshTrendLabel,
                ),
                _MetricCard(
                  title: 'Overspeed Risk',
                  value: summary.overspeedRiskLabel,
                ),
                _MetricCard(
                  title: 'Road Sign Compliance',
                  value: '${summary.compliancePercent.round()}%',
                ),
                _MetricCard(
                  title: 'Driving Behavior Comparison',
                  value: summary.comparisonLabel,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Insights & Recommendations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ...summary.insights.map((insight) => _InsightCard(text: insight)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnalyticsSummary {
  AnalyticsSummary({
    required this.averageScore,
    required this.compliancePercent,
    required this.harshTrendLabel,
    required this.overspeedRiskLabel,
    required this.comparisonLabel,
    required this.header,
    required this.insights,
  });

  final double averageScore;
  final double compliancePercent;
  final String harshTrendLabel;
  final String overspeedRiskLabel;
  final String comparisonLabel;
  final String header;
  final List<String> insights;

  static AnalyticsSummary fromTrips(List<TripAnalytics> trips) {
    final recentTrips = trips.take(7).toList();
    final olderTrips = trips.skip(7).take(7).toList();

    final averageScore = _average(recentTrips.map((trip) => trip.score));
    final recentHarshRate = _average(recentTrips.map((trip) => trip.harshBraking.toDouble()));
    final olderHarshRate = olderTrips.isEmpty
        ? recentHarshRate
        : _average(olderTrips.map((trip) => trip.harshBraking.toDouble()));
    final recentOverspeedRate = _average(recentTrips.map((trip) => trip.overspeed.toDouble()));
    final olderScore = olderTrips.isEmpty
        ? averageScore
        : _average(olderTrips.map((trip) => trip.score));

    final totalEvents = recentTrips.fold<int>(
      0,
      (sum, trip) => sum + trip.harshBraking + trip.overspeed,
    );
    final overspeedEvents = recentTrips.fold<int>(
      0,
      (sum, trip) => sum + trip.overspeed,
    );
    final compliancePercent = totalEvents == 0
        ? 100.0
        : ((totalEvents - overspeedEvents) / totalEvents) * 100;

    final harshTrendLabel = _trendLabel(
      current: recentHarshRate,
      previous: olderHarshRate,
      positiveWhenLower: true,
      stableLabel: 'Stable this week',
      betterLabel: 'Improving',
      worseLabel: 'Needs attention',
    );

    final overspeedRiskLabel = overspeedEvents == 0
        ? 'Under control'
        : overspeedEvents <= 2
            ? '$overspeedEvents mild alerts'
            : '$overspeedEvents high-risk alerts';

    final comparisonDelta = averageScore - olderScore;
    final comparisonLabel = comparisonDelta >= 4
        ? 'Better than last week'
        : comparisonDelta <= -4
            ? 'Lower than last week'
            : 'Holding steady';

    final header =
        'Built from your last ${recentTrips.length} trip${recentTrips.length == 1 ? '' : 's'}.';

    return AnalyticsSummary(
      averageScore: averageScore,
      compliancePercent: compliancePercent.clamp(0, 100),
      harshTrendLabel: harshTrendLabel,
      overspeedRiskLabel: overspeedRiskLabel,
      comparisonLabel: comparisonLabel,
      header: header,
      insights: _buildInsights(
        averageScore: averageScore,
        recentHarshRate: recentHarshRate,
        recentOverspeedRate: recentOverspeedRate,
        compliancePercent: compliancePercent,
        comparisonDelta: comparisonDelta,
      ),
    );
  }

  static List<String> _buildInsights({
    required double averageScore,
    required double recentHarshRate,
    required double recentOverspeedRate,
    required double compliancePercent,
    required double comparisonDelta,
  }) {
    final insights = <String>[];

    if (recentHarshRate >= 2) {
      insights.add('Brake earlier to reduce repeated hard-braking events.');
    } else if (recentHarshRate > 0) {
      insights.add('Your braking is improving. Keep leaving extra stopping distance.');
    } else {
      insights.add('Smooth braking this week. Keep that steady control.');
    }

    if (recentOverspeedRate >= 2) {
      insights.add('Overspeed events are recurring. Ease off sooner near changing speed zones.');
    } else if (recentOverspeedRate > 0) {
      insights.add('A few speed alerts appeared. Watch for posted limits after each sign detection.');
    } else {
      insights.add('Great pace control. You stayed within limits across recent trips.');
    }

    if (compliancePercent < 75) {
      insights.add('Road-sign compliance is low. Slow down quicker after speed-limit and stop signs.');
    } else if (compliancePercent < 90) {
      insights.add('Compliance is decent, with room to improve near posted speed changes.');
    } else {
      insights.add('Strong sign compliance. Keep scanning ahead and reacting early.');
    }

    if (comparisonDelta >= 4) {
      insights.add('Your overall driving score is trending upward compared with earlier trips.');
    } else if (comparisonDelta <= -4) {
      insights.add('Your score dipped versus earlier trips. Focus on one habit at a time this week.');
    } else if (averageScore >= 90) {
      insights.add('You are maintaining a strong safety score. Consistency is your advantage.');
    } else {
      insights.add('Your driving pattern is steady. Small reductions in alerts should lift the score quickly.');
    }

    return insights.take(4).toList();
  }

  static String _trendLabel({
    required double current,
    required double previous,
    required bool positiveWhenLower,
    required String stableLabel,
    required String betterLabel,
    required String worseLabel,
  }) {
    final delta = current - previous;
    if (delta.abs() < 0.4) {
      return stableLabel;
    }

    final improved = positiveWhenLower ? delta < 0 : delta > 0;
    return improved ? betterLabel : worseLabel;
  }

  static double _average(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) {
      return 0;
    }

    final total = list.fold<double>(0, (sum, value) => sum + value);
    return total / list.length;
  }
}

class TripAnalytics {
  TripAnalytics({
    required this.score,
    required this.harshBraking,
    required this.overspeed,
    required this.timestamp,
  });

  final double score;
  final int harshBraking;
  final int overspeed;
  final DateTime timestamp;

  factory TripAnalytics.fromMap(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    return TripAnalytics(
      score: (data['score'] as num?)?.toDouble() ?? 100,
      harshBraking: (data['harshBraking'] as num?)?.toInt() ?? 0,
      overspeed: (data['overspeed'] as num?)?.toInt() ?? 0,
      timestamp: timestamp is Timestamp ? timestamp.toDate() : DateTime(1970),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2E6286),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF345E84),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.35,
        ),
      ),
    );
  }
}

class _EmptyAnalyticsState extends StatelessWidget {
  const _EmptyAnalyticsState();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.insights, size: 56, color: Colors.white70),
              SizedBox(height: 18),
              Text(
                'Analytics will appear after your first trip.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Start driving to generate personalized scores, trends, and recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
