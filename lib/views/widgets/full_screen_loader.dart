import 'package:flutter/material.dart';

class FullScreenLoader extends StatelessWidget {
  final String message;
  final double? progress;
  
  const FullScreenLoader({
    Key? key,
    this.message = 'Loading...',
    this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading spinner
            SizedBox(
              width: 60,
              height: 60,
              child: progress != null 
                ? CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white24,
                  )
                : const CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
            ),
            const SizedBox(height: 24),
            // Loading message
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (progress != null) ...[
              const SizedBox(height: 12),
              Text(
                '${(progress! * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
