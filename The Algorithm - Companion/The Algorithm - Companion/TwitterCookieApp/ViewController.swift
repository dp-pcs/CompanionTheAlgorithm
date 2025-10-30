import UIKit
import WebKit

class ViewController: UIViewController {
    
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var oauthButton: UIButton!
    @IBOutlet weak var twitterAuthButton: UIButton!
    @IBOutlet weak var sendMessageButton: UIButton!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var progressView: UIProgressView!
    
    private let authManager = AuthenticationManager()
    private let cookieManager = CookieManager()
    private let apiClient = APIClient()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUIState()
    }
    
    private func setupUI() {
            // Configure buttons
        oauthButton.layer.cornerRadius = 8
        twitterAuthButton.layer.cornerRadius = 8
        sendMessageButton.layer.cornerRadius = 8
        
            // Configure text field
        messageTextField.layer.borderWidth = 1
        messageTextField.layer.borderColor = UIColor.systemGray4.cgColor
        messageTextField.layer.cornerRadius = 8
        messageTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        messageTextField.leftViewMode = .always
        
            // Hide progress view initially
        progressView.isHidden = true
        
            // Set initial status
        statusLabel.text = "Ready to authenticate"
        statusLabel.textColor = .systemBlue
    }
    
    private func updateUIState() {
        let hasOAuthToken = authManager.hasValidOAuthToken()
        let hasCookies = cookieManager.hasValidCookies()
        
        oauthButton.isEnabled = !hasOAuthToken
        twitterAuthButton.isEnabled = hasOAuthToken && !hasCookies
        sendMessageButton.isEnabled = hasOAuthToken && hasCookies
        messageTextField.isEnabled = hasOAuthToken && hasCookies
        
        if hasOAuthToken && hasCookies {
            statusLabel.text = "✅ Ready to send messages"
            statusLabel.textColor = .systemGreen
        } else if hasOAuthToken {
            statusLabel.text = "🔑 OAuth complete. Now authenticate with X.com"
            statusLabel.textColor = .systemOrange
        } else {
            statusLabel.text = "👋 Start by authenticating with your service"
            statusLabel.textColor = .systemBlue
        }
    }
    
        // MARK: - Button Actions
    
    @IBAction func oauthButtonTapped(_ sender: UIButton) {
        showProgress(message: "Authenticating with your service...")
        
        authManager.authenticateWithOAuth { [weak self] success, error in
            DispatchQueue.main.async {
                self?.hideProgress()
                if success {
                    self?.updateUIState()
                    self?.showAlert(title: "Success", message: "OAuth authentication completed!")
                } else {
                    self?.showAlert(title: "Error", message: error?.localizedDescription ?? "OAuth authentication failed")
                }
            }
        }
    }
    
    @IBAction func twitterAuthButtonTapped(_ sender: UIButton) {
        showProgress(message: "Authenticating with X.com...")
        
        authManager.authenticateWithTwitter(from: self) { [weak self] cookies, error in
            DispatchQueue.main.async {
                self?.hideProgress()
                if let cookies = cookies {
                    self?.cookieManager.storeCookies(cookies)
                    self?.sendCookiesToBackend(cookies)
                    self?.updateUIState()
                    self?.showAlert(title: "Success", message: "X.com authentication completed!")
                } else {
                    self?.showAlert(title: "Error", message: error?.localizedDescription ?? "X.com authentication failed")
                }
            }
        }
    }
    
    @IBAction func sendMessageButtonTapped(_ sender: UIButton) {
        guard let message = messageTextField.text, !message.isEmpty else {
            showAlert(title: "Error", message: "Please enter a message")
            return
        }
        
        showProgress(message: "Sending message...")
        
        apiClient.sendMessage(message) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.hideProgress()
                if success {
                    self?.messageTextField.text = ""
                    self?.showAlert(title: "Success", message: "Message sent successfully!")
                } else {
                    self?.showAlert(title: "Error", message: error?.localizedDescription ?? "Failed to send message")
                }
            }
        }
    }
    
        // MARK: - Helper Methods
    
    private func sendCookiesToBackend(_ cookies: [HTTPCookie]) {
        apiClient.storeCookies(cookies) { [weak self] success, error in
            if !success {
                print("Warning: Failed to store cookies on backend: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func showProgress(message: String) {
        statusLabel.text = message
        progressView.isHidden = false
        progressView.setProgress(0.0, animated: false)
        
            // Animate progress
        UIView.animate(withDuration: 2.0) {
            self.progressView.setProgress(0.8, animated: true)
        }
    }
    
    private func hideProgress() {
        progressView.isHidden = true
        progressView.setProgress(0.0, animated: false)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

    // MARK: - Text Field Delegate

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField == messageTextField {
            sendMessageButtonTapped(sendMessageButton)
        }
        return true
    }
}
