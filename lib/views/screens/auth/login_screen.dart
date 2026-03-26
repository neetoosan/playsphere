import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:play_sphere/views/screens/auth/signup_screen.dart';
import 'package:get/get.dart';
import '../../../constants.dart';
import '../../widgets/text_input.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 
                         MediaQuery.of(context).padding.top - 
                         MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 100,
                    child: Image.asset(
                      'assets/logo.png', 
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "PlaySphere",
                    style: TextStyle(
                        color: buttonColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "Login",
                    style: TextStyle(
                        fontSize: 23,
                        color: secondaryColor,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(
                    height: 25,
                  ),
              
                  //<------------------- text fields ------------------->
                  Container(
                    width: MediaQuery.of(context).size.width,
                    margin: kIsWeb
                        ? const EdgeInsets.symmetric(horizontal: 350)
                        : const EdgeInsets.symmetric(horizontal: 25),
                    child: TextInputField(
                      controller: _emailController,
                      labelText: "Enter email",
                      icon: Icons.email,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width,
                    margin: kIsWeb
                        ? const EdgeInsets.symmetric(horizontal: 350)
                        : const EdgeInsets.symmetric(horizontal: 25),
                    child: TextInputField(
                      controller: _passwordController,
                      labelText: "Enter Password",
                      icon: Icons.lock,
                      isObscure: true,
                    ),
                  ),
                  const SizedBox(
                    height: 15,
                  ),
              
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 35.0),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => _buildForgotPasswordDialog(context),
                          );
                        },
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
              
                  //<------------------- Login button ------------------->
                  InkWell(
                    onTap: () => authController.loginUser(
                        _emailController.text, _passwordController.text),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      margin: kIsWeb
                          ? const EdgeInsets.symmetric(horizontal: 350)
                          : const EdgeInsets.symmetric(horizontal: 25),
                      height: 55,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: buttonColor,
                          borderRadius: const BorderRadius.all(Radius.circular(27.5))),
                      child: const Text("Log In",
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 20)),
                    ),
                  ),
                  const SizedBox(height: 18),
              
                  //<------------------- sign up text row ------------------->
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don\'t have an account? ",
                          style: TextStyle(fontSize: 16)),
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => SignupScreen()));
                        },
                        child: Text("Register Now!",
                            style: TextStyle(fontSize: 18, color: secondaryColor)),
                      ),
                  ],
                  ),
                  const SizedBox(height: 20),

                  // OR Divider
                  Container(
                    margin: kIsWeb
                        ? const EdgeInsets.symmetric(horizontal: 350)
                        : const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey[400],
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey[400],
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Google Sign-In Button
                  InkWell(
                    onTap: () => authController.signInWithGoogle(),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      margin: kIsWeb
                          ? const EdgeInsets.symmetric(horizontal: 350)
                          : const EdgeInsets.symmetric(horizontal: 25),
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: buttonColor!),
                        borderRadius: const BorderRadius.all(Radius.circular(25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/google.png',
                            width: 24.0,
                            height: 24.0,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Continue with Google",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordDialog(BuildContext context) {
  final TextEditingController _resetEmailController = TextEditingController();

  return AlertDialog(
    title: const Text('Forgot Password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter your email to receive a password reset link'),
        const SizedBox(height: 15),
        TextField(
          controller: _resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop(); // Close dialog
        },
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          final email = _resetEmailController.text.trim();
          if (email.isNotEmpty) {
            Navigator.of(context).pop();
            authController.resetPassword(email);
          } else {
            Get.snackbar(
              'Missing Field',
              'Please enter your email address',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.white,
              colorText: Colors.red,
            );
          }
        },
        child: Text(
          "Send",
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
}