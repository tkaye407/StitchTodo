//
//  LoginViewController.swift
//  TodoStitch
//
//  Created by Tyler Kaye on 9/10/18.
//  Copyright © 2018 Tyler Kaye. All rights reserved.
//

import UIKit
import StitchCore
import FacebookLogin
import FacebookCore
import GoogleSignIn

class LoginViewController: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate, LoginButtonDelegate {
    @IBOutlet weak var loginStack: UIStackView!
    
    // Stitch variables
    var stitchClient: StitchAppClient!
    static var provider: StitchProviderType?
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    //
    //                                  UI / SETUP METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    override func viewDidLoad() {
        super.viewDidLoad()
        self.stitchClient = Stitch.defaultAppClient!
        
        // Google Setup
        GIDSignIn.sharedInstance().clientID = "298015299187-bbpq0dsbepconb81o2sf035s18kqupal.apps.googleusercontent.com"
        GIDSignIn.sharedInstance().serverClientID = "298015299187-ev620ecjc5gb824jq1uf39tftodlbjvj.apps.googleusercontent.com"
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        
        // Google UI Setup
        let googleSignInButton = GIDSignInButton()
        loginStack.addArrangedSubview(googleSignInButton)
        
        // Facebook UI Setup
        let facebookLoginButton = LoginButton(readPermissions: [ .publicProfile, .email])
        facebookLoginButton.delegate = self
        loginStack.addArrangedSubview(facebookLoginButton)
    }
    
    //////////////////////////////////////////////////////////////////////////////////////
    //
    //                          FACEBOOK LOGIN DELEGATE METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    func loginButtonDidCompleteLogin(_ loginButton: LoginButton, result: LoginResult) {
        switch result {
        case .success(_, _, let token):
            let credential = FacebookCredential.init(withAccessToken: token.authenticationToken)
            stitchClient.auth.login(withCredential: credential, {result in
                switch result {
                case .success(_):
                    // Logic to go to next ViewController
                    LoginViewController.provider = StitchProviderType.facebook
                    self.dismiss(animated: true, completion: nil)
                case .failure(let error):
                    print("Failed to login to Stitch with Facebook OAuth Credentials: \(error.localizedDescription)")
                    let alertController = UIAlertController(title: "Login Error", message: "Failed to Login with Facebook \(error.localizedDescription)", preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
            })
        case .failed(let error):
            print("Facebook Login Failed with error: \(error.localizedDescription)")
            let alertController = UIAlertController(title: "Login Error", message: "Facebook login failed with error: \(error.localizedDescription)", preferredStyle: .alert)
            self.present(alertController, animated: true, completion: nil)
        default:
            break
        }
    }
    
    func loginButtonDidLogOut(_ loginButton: LoginButton) {
        print("Disconnected from Facebook Login")
    }
    
    
    //////////////////////////////////////////////////////////////////////////////////////
    //
    //                          GOOGLE LOGIN DELEGATE METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error == nil {
            let credential = GoogleCredential.init(withAuthCode: user.serverAuthCode)
            stitchClient.auth.login(withCredential: credential, {result in
                switch result {
                case .success(_):
                    // Logic to go to next ViewController
                    LoginViewController.provider = StitchProviderType.google
                    self.dismiss(animated: true, completion: nil)
                case .failure(let error):
                    print("Failed to login to Stitch with Google OAuth Credentials: \(error.localizedDescription)")
                    let alertController = UIAlertController(title: "Login Error", message: "Failed to Login with Google \(error.localizedDescription)", preferredStyle: .alert)
                    self.present(alertController, animated: true, completion: nil)
                }
            })
        }
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        print("Disconnected from Google. error: \(error.localizedDescription)")
    }

    
    //////////////////////////////////////////////////////////////////////////////////////
    //
    //                          ANONYMOUS LOGIN METHODS
    //
    //////////////////////////////////////////////////////////////////////////////////////
    @IBAction func loginWithAnonymousCredentials(_ sender: Any) {
        stitchClient.auth.login(withCredential: AnonymousCredential.init()) {result in
            switch result {
            case .success:
                LoginViewController.provider = StitchProviderType.anonymous
                self.dismiss(animated: true, completion: nil)
            case .failure(let error):
                print("failed to log in anonymously: \(error)")
            }
        }
    }
}
