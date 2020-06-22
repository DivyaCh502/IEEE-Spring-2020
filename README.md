# Covid Contact Tracker

## Deployment dependencies

Before performing a Deployment, it is assumed that the following have been set up:

- Xcode 11.2.1+
- OS X 10.14.5 or above
- two iPhones with iOS 12.0+

## Organization of Submission
- `src` – this directory contains the source code 
- `src/CovidContactTracker.xcworkspace` – Xcode workspace to open.
- `docs` – this directory contains the documents for this application, including this
deployment guide.

## 3rd party Libraries

- AppCenter v.3.1.1
- [SwiftEx/Int](https://gitlab.com/seriyvolk83/SwiftEx) v.0.3.75 (`branch => 'covid19'`)
- [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) v.4.3.0
- [TCN Client iOS](https://github.com/seriyvolk83/tcn-client-ios.git) (`fix2` branch) 

## Configuration

Configuration is provided in `configuration.plist` in `CovidContactTracking/Supporting Files` group:
- `appCenterSecret` - The AppCenter secret
- `clientId` - the client ID
- `cognitoLoginUrl` - the login URL, e.g. "https://tc-tcn-tracker.auth.us-east-1.amazoncognito.com/oauth2/authorize?response_type=code&client_id=%clientId%&redirect_uri=app://callback"
- `cognitoGetTokenUrl` - the token refresh URL, the `code` will be concatenated at the end, e.g. "https://tc-tcn-tracker.auth.us-east-1.amazoncognito.com/oauth2/token?grant_type=authorization_code&client_id=%clientId%&redirect_uri=app://callback&code="
- `cognitoGetRefreshTokenUrl` - the refresh token URL, `refresh_token` will be concatenated at the end, e.g. "https://tc-tcn-tracker.auth.us-east-1.amazoncognito.com/oauth2/token?grant_type=refresh_token&client_id=%clientId%&redirect_uri=app://callback&refresh_token=" 
- `cognitoSecret` - Cognito secret.
- `baseUrl` - base URL, e.g. "https://ib9ntcqot3.execute-api.us-east-1.amazonaws.com/v4"
- `backgroundFetchInterval` - the background fetch interval in seconds, e.g. 3600 (1 hour)
- `reminderNotificationHour` - the hour when daily notification will be shown, e.g. 11 for "11:00 AM", 21 for "9:00 PM"
- `reminderNotificationMinute` - the minute when daily notification will be shown, e.g. 0 for "11:00 AM"
The two values are used to schedule notifcations: 5 daily notificaitons and after that an every week notification.
If the values are -1, then the notiifcations will be scheduled in same hours as last app opening. If non-negative, then in exactly these hours. 

### Background tasks

On iOS <=12 the all requests background fetch. On iOS 13+ the app schedules background task. They call one and the same method to check the state of the user's account.
The same method is called when user pulls to refresh on Contacts screen. The device should have background tasks on in Settings and the app should have permissions for using background tasks.
There is no way to check if background tasks fails. If user receives a local notification related to potentical contact with an infected user, then probably it was invoked after background check.

### Start and stop tracing

`UserDefaults.shouldStartBluetooth` defines the desired state for the tracing. It's set to `true` by default and is changed when user taps on "Start/Stop tracing" button. The initial button state is taken from this field. When user taps the button in UI, it starts/stops tracing by invoking TCN library methods which start/stop advitising and discovering bluetooth devices, and updates `UserDefaults.shouldStartBluetooth` state. This happens only if BLE is enabled. If the last time user had enabled the tracing (`UserDefaults.shouldStartBluetooth==true`) and for some reason BLE was turned off, then it will be started automatically once user will enable BLE again (see `MainViewController.checkStateAndStartIfNeeded()`).
The TCN library's `TCNBluetoothService.start()` method (see `AppDelegate.startTCN()`) is called only if `AppDelegate.wasLaunched == true`. This field controls the calls to the library and prevent from starting/stopping the TCN framework when it's already started/stopped.

### Push notifications

When turned on in Settings (in general and for the app) the app will receive push notifications. Nothing special needed to configure them. All is done on the backend. The app only sends device token to the backed.

### TCN Memo Field

- [https://github.com/TCNCoalition/TCN](https://github.com/TCNCoalition/TCN), check "Memo Structure"
- `memo type` is set to 0x1
- `memo data` is set to the current signed in user's `sub` field (retrieved through Cognito) encoded in UTF-8

## Deployment

Run `pod install` to update the libraries.

### Run the app

To build and run the app on a real device you will need to do the following:

1. Open `src/CovidContactTracker.xcworkspace` in Xcode
2. Select *CovidContactTracker* scheme from the top left drop down list.
3. Select your iPhone/iPad from the top left dropdown list.
4. Click menu Product -> Run (Cmd+R)
