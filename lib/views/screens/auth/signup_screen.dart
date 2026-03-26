import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:play_sphere/views/screens/auth/login_screen.dart';
import 'package:play_sphere/views/screens/auth/email_verification_screen.dart';
import '../../../constants.dart';
import '../../../controllers/auth_controllers.dart';
import '../../widgets/text_input.dart';

class SignupScreen extends StatefulWidget {
  SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

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
            Text(
              "PlaySphere",
              style: TextStyle(
                color: secondaryColor,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 25),

            // <------------------- Avatar and upload img icon (Optional) ------------------->
            Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: authController.profilePhoto != null
                          ? FileImage(authController.profilePhoto!)
                          : const NetworkImage(defaultProfileImageUrl) as ImageProvider,
                      backgroundColor: Colors.grey,
                    ),
                    Positioned(
                      bottom: 30,
                      left: 28,
                      child: IconButton(
                        icon: Icon(
                          authController.profilePhoto != null 
                              ? Icons.check_circle 
                              : Icons.add_a_photo, 
                          color: authController.profilePhoto != null 
                              ? Colors.green 
                              : secondaryColor, 
                          size: 34
                        ),
                        onPressed: () => authController.pickImage(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Profile Picture (Optional)",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // <------------------- text fields ------------------->
            Container(
              width: MediaQuery.of(context).size.width,
              margin: kIsWeb
                  ? const EdgeInsets.symmetric(horizontal: 350)
                  : const EdgeInsets.symmetric(horizontal: 25),
              child: TextInputField(
                controller: _emailController,
                labelText: "Enter Email",
                icon: Icons.email,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              width: MediaQuery.of(context).size.width,
              margin: kIsWeb
                  ? const EdgeInsets.symmetric(horizontal: 350)
                  : const EdgeInsets.symmetric(horizontal: 25),
              child: TextInputField(
                controller: _usernameController,
                labelText: "Enter Username",
                icon: Icons.person,
                isObscure: false,
              ),
            ),
            const SizedBox(height: 15),
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
            const SizedBox(height: 15),

            // <------------------- sign up button ------------------->
            InkWell(
              onTap: () async {
                String res = await authController.registerUser(
                  _usernameController.text.trim(),
                  _emailController.text.trim(),
                  _passwordController.text.trim(),
                  authController.profilePhoto,
                );

                if (!mounted) return;

                if (res == "success") {
                  // Navigate to email verification screen
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const EmailVerificationScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res)),
                  );
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: kIsWeb
                    ? const EdgeInsets.symmetric(horizontal: 350)
                    : const EdgeInsets.symmetric(horizontal: 25),
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: const BorderRadius.all(Radius.circular(25)),
                ),
                child: const Text(
                  "Sign up",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // <------------------- login text row ------------------->
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account? ",
                    style: TextStyle(fontSize: 16)),
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  child: Text(
                    "Login",
                    style: TextStyle(fontSize: 18, color: secondaryColor),
                  ),
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
            )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
