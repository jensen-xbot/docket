import SwiftUI
import AuthenticationServices
import _Concurrency

struct AuthView: View {
    @Bindable var authManager: AuthManager
    
    @State private var email = ""
    @State private var showEmailSent = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App branding
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                Text("Docket")
                    .font(.system(size: 36, weight: .bold))
                Text("Simple, fast task management")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Sign-in options
            VStack(spacing: 16) {
                // Apple Sign-In (uses native button, result passed to AuthManager)
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        _Concurrency.Task {
                            await authManager.handleAppleSignIn(result: result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                
                // Email magic link
                if !showEmailSent {
                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        Button(action: {
                            _Concurrency.Task {
                                await authManager.signInWithEmail(email)
                                if authManager.errorMessage == nil {
                                    showEmailSent = true
                                }
                            }
                        }) {
                            Text("Send magic link")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(email.isEmpty ? Color.gray : Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .disabled(!email.isValidEmail)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Text("Check your email")
                            .font(.headline)
                        Text("We sent a magic link to \(email)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Use a different email") {
                            showEmailSent = false
                            email = ""
                        }
                        .font(.subheadline)
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .padding(.horizontal, 32)
            
            if authManager.isLoading {
                ProgressView()
            }
            
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// Google "G" logo drawn with SwiftUI
struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let radius = min(w, h) / 2
            let lineWidth = radius * 0.22

            // Blue arc (top-right)
            var bluePath = Path()
            bluePath.addArc(center: center, radius: radius - lineWidth / 2,
                           startAngle: .degrees(-45), endAngle: .degrees(-135),
                           clockwise: true)
            context.stroke(bluePath, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)),
                          lineWidth: lineWidth)

            // Green arc (bottom-right)
            var greenPath = Path()
            greenPath.addArc(center: center, radius: radius - lineWidth / 2,
                            startAngle: .degrees(45), endAngle: .degrees(-45),
                            clockwise: true)
            context.stroke(greenPath, with: .color(Color(red: 0.13, green: 0.69, blue: 0.30)),
                          lineWidth: lineWidth)

            // Yellow arc (bottom-left)
            var yellowPath = Path()
            yellowPath.addArc(center: center, radius: radius - lineWidth / 2,
                             startAngle: .degrees(135), endAngle: .degrees(45),
                             clockwise: true)
            context.stroke(yellowPath, with: .color(Color(red: 0.98, green: 0.74, blue: 0.02)),
                          lineWidth: lineWidth)

            // Red arc (top-left)
            var redPath = Path()
            redPath.addArc(center: center, radius: radius - lineWidth / 2,
                          startAngle: .degrees(-135), endAngle: .degrees(135),
                          clockwise: true)
            context.stroke(redPath, with: .color(Color(red: 0.92, green: 0.26, blue: 0.21)),
                          lineWidth: lineWidth)

            // Horizontal bar (the dash of the G)
            let barRect = CGRect(
                x: center.x - lineWidth * 0.1,
                y: center.y - lineWidth / 2,
                width: radius * 0.55,
                height: lineWidth
            )
            context.fill(Path(barRect), with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
    }
}

#Preview {
    AuthView(authManager: AuthManager())
}
