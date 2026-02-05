import 'package:flutter/material.dart';

class GoogleApple extends StatelessWidget {
  final String googleapple;
  const GoogleApple({super.key, required this.googleapple});

  @override
  Widget build(BuildContext context) {
    return  Container(
      height: 60,
      width: 60,
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(20),
          color: Colors.grey[200]
      ),
      child: Image.asset(
        googleapple,
      ) ,
    );
  }
}
