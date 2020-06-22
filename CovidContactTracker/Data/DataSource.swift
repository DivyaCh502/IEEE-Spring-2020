//
//  DataSource.swift
//  CovidContactTracking
//
//  Created by Volkov Alexander on 5/6/20.
//  Copyright © 2020 Volkov Alexander. All rights reserved.
//

import Foundation
import SwiftEx
import RxSwift
import Alamofire
import RxAlamofire
import SwiftyJSON
import TCNClient

typealias DataSource = RestServiceApi

extension RestServiceApi {
    
    static let AUTH_HEADER = "Authorization"

    // MARK: - AUTH
    
    /// Get token
    /// - Parameter code: the code
    static func getToken(by code: String) -> Observable<AuthResponse> {
        return requestString(.post, url: Configuration.cognitoGetTokenUrl + code,
                             headers: [
                                "Content-Type": ContentType.FORM.rawValue
        ]).map({ (result: Any) -> AuthResponse in
            let value = try JSON(result).decode(AuthResponse.self)
            AuthenticationUtil.processCredentials(value)
            return value
        })
    }
    
    // MARK: - USER
    static func postUser(cognitoId: String?, email: String? = nil, deviceToken: String?) -> Observable<UserPostResponse> {
        guard let cognitoId = cognitoId else { return Observable.error("cognitoId must be not nil")}
        var params: [String: Any] = [
            "cognitoId": cognitoId,
            "osType": "iOS",
            "appInstallationId": "string",
            "appVendorId": UIDevice.current.identifierForVendor?.uuidString ?? "Unknown",
            "allowNotification": deviceToken != nil,
        ]
        if let token = deviceToken {
            params["token"] = token
        }
        if let email = email {
            params["email"] = email
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            params["appInstallationId"] = bundleIdentifier
        }
        return tryPost(url: url("/user"), parameters: params)
    }
    
    
    /// Get user info
    static func getUser() -> Observable<UserResponse> {
        return tryGet(url: url("/user"))
    }
    
    /// Upload a report
    static func upload(report: SignedReport) -> Observable<Void> {
        do {
            let data = try report.serializedData()
            let dataEncoded = data.base64EncodedData()
            #if DEBUG
            assert(data == Data(base64Encoded: data.base64EncodedData())!)
            do {
                print("upload report ->>\(data.base64EncodedString())")
                let r = try SignedReport(serializedData: data)
                print(r == report)
            }
            catch let error {
                print("ERROR!!!: \(error)")
            }
            #endif
            return tryPost(data: dataEncoded, toUrl: url("/tcnreport")).void()
        }
        catch let error {
            return Observable.error(error)
        }
    }
    
    /// Get TCN reports
    static func getReports() -> Observable<[SignedReport]> {
        return tryGet(url: url("/tcnreport")).map { (strings: [String]) -> [SignedReport] in
                let data: [Data] = strings.map{Data(base64Encoded: $0)!}
                var reports = [SignedReport]()
                for d in data {
                    do {
                        let r = try SignedReport(serializedData: d)
                        reports.append(r)
                    }
                    catch {
                        print("!!!!!: Incorrect report data: \(d.base64EncodedString())")
                    }
                }
                return reports
        }
    }
    
    /// Post user's exposure
    static func reportExposure(_ infectedByContacts: [Contact]) -> Observable<Void> {
        guard !infectedByContacts.isEmpty else { return Observable.just(())}
        var list = [Observable<Void>]()
        for c in infectedByContacts {
            let params: [String: Any] = [
                "tcnReportUser": c.tcnReportUser,
                "distance": c.distance,
                "foundTime": Int(c.foundTime),
                "lastSeenTime": Int(c.lastSeenTime)
            ]
            list.append(tryPost(url: url("/user/report"), parameters: params))
        }
        return Observable.combineLatest(list).void()
    }
    
    // MARK: - Private
    
    private static func url(_ endpoint: String) -> String {
        return Configuration.baseUrl + endpoint
    }
    
    /// Get request
    ///
    /// - Parameter url: URL
    /// - Returns: the observable
    public static func tryGet<T: Decodable>(url: URLConvertible, parameters: [String: Any] = [:]) -> Observable<T> {
        var url = url
        if !parameters.isEmpty {
            url = "\(url)?\(parameters.toURLString())"
        }
        return tryRequest(.get, url: url)
            .map { (json) -> T in
                return try json.decode(T.self)
        }
    }
    
    /// Get request
    ///
    /// - Parameter url: URL
    /// - Returns: the observable
    public static func tryGget(url: URLConvertible) -> Observable<Void> {
        return tryRequest(.get, url: url).map { _ in }
    }
    
    /// POST request
    ///
    /// - Parameter url: URL
    /// - Returns: the observable
    public static func tryPost<T: Decodable>(url: URLConvertible, parameters: [String: Any]) -> Observable<T> {
        return tryRequest(.post, url: url, parameters: parameters)
            .map { (json) -> T in
                return try json.decode(T.self)
        }
    }
    
    public static func tryPost(url: URLConvertible, parameters: [String: Any]) -> Observable<Void> {
        return tryRequest(.post, url: url, parameters: parameters)
            .map { (json) -> Void in
                return ()
        }
    }
    
    /// Request to API with 401 handling
    ///
    /// - Parameters:
    ///   - method: the method
    ///   - url: the URL
    ///   - parameters: the parameters
    ///   - headers: the headers
    ///   - encoding: the encoding
    /// - Returns: the observable
    public static func tryRequest(_ method: HTTPMethod,
                               url: URLConvertible,
                               parameters: [String: Any]? = nil,
                               headers: [String: String] = [:],
                               encoding: ParameterEncoding = JSONEncoding.default) -> Observable<JSON> {
        var sendRequest: URLRequest!
        let createRequest = { () -> Observable<(HTTPURLResponse, Data)> in
            var headers = headers
            for (k,v) in RestServiceApi.headers {
                headers[k] = v
            }
            let r = RxAlamofire
                .request(method, url, parameters: parameters, encoding: encoding, headers: headers)
                .observeOn(ConcurrentDispatchQueueScheduler.init(qos: .default))
                .validate(contentType: ["application/json"])
                .do(onNext: { (request) in
                    #if DEBUG
                    if let request = request.request {
                        sendRequest = request
                        logRequestEx(request)
                    }
                    #endif
                })
                .responseData()
            return r
        }
        var needLog = false
        return createRequest()
            .flatMap({ (result: HTTPURLResponse, data: Data) -> Observable<(HTTPURLResponse, Data)> in
                #if DEBUG
                logResponseEx(data as AnyObject, forRequest: sendRequest, response: result)
                #endif
                if result.statusCode == 401 {
                    DataSource.logs.append("REFRESHING TOKEN...")
                    return refreshToken().flatMap { (updated) -> Observable<(HTTPURLResponse, Data)> in
                        needLog = updated
                        return updated ? createRequest() : Observable.just((result, data))
                    }
                }
                return Observable.just((result, data))
            })
            .flatMap { (result: HTTPURLResponse, data: Data) -> Observable<Any> in
                #if DEBUG
                if needLog {
                    logResponseEx(data as AnyObject, forRequest: sendRequest, response: result)
                }
                #endif
                if result.statusCode == 401 {
                    let error: Error? = String(data: data, encoding: .utf8)
                    return Observable.error(error as? String ?? NSLocalizedString("Unauthorized", comment: "Unauthorized"))
                }
                else if result.statusCode >= 400 {
                    let error: Error? = String(data: data, encoding: .utf8)
                    return Observable.error(error as? String ?? NSLocalizedString("Unknown error", comment: "Unknown error"))
                }
                if data.isEmpty {
                    return Observable.just(JSON.null)
                }
                return Observable.just(JSON(data))
        }
        .map({ (result: Any) -> JSON in
            return JSON(result)
        })
    }
    
    private static func refreshToken() -> Observable<Bool> {
        guard let response = AuthenticationUtil.response, let refreshToken = response.refresh_token else { return Observable.just(false) }
        return requestString(.post, url: Configuration.cognitoGetRefreshTokenUrl + refreshToken,
                             headers: [
                                "Content-Type": ContentType.FORM.rawValue
        ]).map({ (result: Any) -> Bool in
            let value = try JSON(result).decode(AuthResponse.self)
            AuthenticationUtil.processCredentials(value)
            return true
        })
    }
    
    private static func tryLog(_ result: DataResponse<Any>) {
        #if DEBUG
        if let request = result.request {
            logRequestEx(request)
            if let response = result.response {
                logResponseEx(result.value as AnyObject, forRequest: request, response: response)
            }
        }
        #endif
    }
    
    /// Request to API
    ///
    /// - Parameters:
    ///   - method: the method
    ///   - url: the URL
    ///   - parameters: the parameters
    ///   - headers: the headers
    ///   - encoding: the encoding
    /// - Returns: the observable
    public static func requestString(_ method: HTTPMethod,
                                     url: URLConvertible,
                                     parameters: [String: Any]? = nil,
                                     headers: [String: String] = [:],
                                     encoding: ParameterEncoding = URLEncoding.default) -> Observable<Data> {
        var allHeaders = headers
        for (k,v) in headers {
            allHeaders[k] = v
        }
        var sendRequest: URLRequest!
        return RxAlamofire
            .request(method, url, parameters: parameters, encoding: encoding, headers: allHeaders)
            .observeOn(ConcurrentDispatchQueueScheduler.init(qos: .default))
            .do(onNext: { (request) in
                #if DEBUG
                if let request = request.request {
                    sendRequest = request
                    logRequestEx(request)
                }
                #endif
            })
            .responseData()
            .flatMap { (result: HTTPURLResponse, data: Data) -> Observable<Data> in
                #if DEBUG
                logResponseEx(data as AnyObject, forRequest: sendRequest, response: result)
                #endif
                if result.statusCode == 401 {
                    if let callback401 = callback401 { callback401() }
                    return Observable.error(NSLocalizedString("Unauthorized", comment: "Unauthorized"))
                }
                else if result.statusCode >= 400 {
                    let error = String(data: data, encoding: .utf8)
                    if let json = try? JSON(data: data) {
                        if json["error"].string == "invalid_grant"
                        || json["error"].string == "invalid_client"
                        || (json["error"].string?.hasPrefix("invalid_") ?? false) {
                            if let callback401 = callback401 { callback401() }
                        }
                    }
                    return Observable.error(error ?? NSLocalizedString("Unknown error", comment: "Unknown error"))
                }
                return Observable.just(data)
        }
    }
    
//    /// Upload JSON
//    ///
//    /// - Parameters:
//    ///   - string: the string
//    ///   - url: URL
//    ///   - parameters: the parameters
//    ///   - headers: the headers
//    /// - Returns: sequence
//    public static func upload(report: ReportUpload, toUrl url: String, headers: [String: String] = [:]) ->  Observable<Data?> {
//        return Observable<Data?>.create({observer in
//            var request = URLRequest(url: URL(string: url)!)
//            request.httpMethod = "POST"
//            for (k,v) in RestServiceApi.headers {
//                request.addValue(v, forHTTPHeaderField: k)
//            }
//            for (k,v) in headers {
//                request.addValue(v, forHTTPHeaderField: k)
//            }
//            // set encoding to base64 and snake_case
//            let encoder = JSONEncoder()
//            encoder.keyEncodingStrategy = .convertToSnakeCase
//            encoder.dataEncodingStrategy = .base64
//
//            do {
//                request.httpBody = try encoder.encode(report)
//            }
//            catch let error {
//                observer.onError(error)
//            }
//
//            request.addValue(ContentType.JSON.rawValue, forHTTPHeaderField: "Content-Type")
//            #if DEBUG
//            self.logRequestEx(request)
//            #endif
//            let task = URLSession.shared.dataTask(with: request) { data, response, error in
//                #if DEBUG
//                self.logResponseEx((data ?? Data()) as AnyObject, forRequest: request, response: response)
//                #endif
//                if let error = error {
//                    observer.onError(error)
//                    return
//                }
//                else if let statusCode = (response as? HTTPURLResponse)?.statusCode {
//                    if let data = data {
//                        if data.count < 10000 && !OPTION_PRINT_REST_API_LOGS {
//                            print("HTTP \(statusCode)" + String(data: data, encoding: .utf8)!)
//                        }
//                        observer.onNext(data)
//                        observer.onCompleted()
//                        return
//                    }
//                }
//                observer.onError("Invalid response")
//            }
//            task.resume()
//            return Disposables.create {
//                task.cancel()
//            }
//        })
//    }
    
    // MARK: -
    
    public static func tryPost(data: Data, toUrl url: String) ->  Observable<Data?> {
        return createPostRequestObservable(data: data, toUrl: url).flatMap { (resultData, error) -> Observable<Data?> in
            if let _ = error { // 401
                // Try refresh token
                return refreshToken().flatMap { (updated) -> Observable<Data?> in
                    if updated {
                        return createPostRequestObservable(data: data, toUrl: url).flatMap { (res, error) -> Observable<Data?> in
                            if let error = error { return Observable.error(error) }
                            return Observable.just(res)
                        }
                    }
                    return Observable.just(data)
                }
            }
            else {
                return Observable.just(resultData)
            }
        }
    }
    
//    /// POST data
//    ///
//    /// - Parameters:
//    ///   - string: the string
//    ///   - url: URL
//    ///   - parameters: the parameters
//    ///   - headers: the headers
//    /// - Returns: sequence
//    public static func post(data: Data, toUrl url: String, headers: [String: String] = [:]) ->  Observable<Data?> {
//        return Observable<Data?>.create({observer in
//            let request = createPostRequest(data: data, toUrl: url, headers: headers)
//            let task = URLSession.shared.dataTask(with: request) { data, response, error in
//                #if DEBUG
//                self.logResponseEx((data ?? Data()) as AnyObject, forRequest: request, response: response)
//                #endif
//                if let error = error { observer.onError(error);  return }
//                else if let statusCode = (response as? HTTPURLResponse)?.statusCode {
//                    if statusCode == 401 {
//                        observer.onError(NSLocalizedString("Unauthorized", comment: "Unauthorized"))
//                        return
//                    }
//                    else if statusCode >= 400 {
//                        if let data = data, let error = String(data: data, encoding: .utf8) { observer.onError(error) }
//                        else { observer.onError(NSLocalizedString("Unknown error", comment: "Unknown error")) }
//                        return
//                    }
//                    else if let data = data {
//                        if data.count < 10000 && !OPTION_PRINT_REST_API_LOGS {
//                            print("HTTP \(statusCode)" + String(data: data, encoding: .utf8)!)
//                        }
//                        observer.onNext(data)
//                        observer.onCompleted()
//                        return
//                    }
//                }
//                observer.onError("Invalid response")
//            }
//            task.resume()
//            return Disposables.create {
//                task.cancel()
//            }
//        })
//    }
    
    public static func createPostRequestObservable(data: Data, toUrl url: String, headers: [String: String] = [:]) -> Observable<(Data?, Error?)> {
        return Observable<(Data?, Error?)>.create({observer in
            let request = createPostRequest(data: data, toUrl: url, headers: headers)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                #if DEBUG
                self.logResponseEx((data ?? Data()) as AnyObject, forRequest: request, response: response)
                #endif
                if let error = error { observer.onError(error);  return }
                else if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if statusCode == 401 {
                        observer.onNext((data, NSLocalizedString("Unauthorized", comment: "Unauthorized")))
                        observer.onCompleted()
                        return
                    }
                    else if statusCode >= 400 {
                        if let data = data, let error = String(data: data, encoding: .utf8) { observer.onError(error) }
                        else { observer.onError(NSLocalizedString("Unknown error", comment: "Unknown error")) }
                        return
                    }
                    else if let data = data {
                        if data.count < 10000 && !OPTION_PRINT_REST_API_LOGS {
                            print("HTTP \(statusCode)" + String(data: data, encoding: .utf8)!)
                        }
                        observer.onNext((data, nil))
                        observer.onCompleted()
                        return
                    }
                }
                observer.onError("Invalid response")
            }
            task.resume()
            return Disposables.create {
                task.cancel()
            }
        })
    }
    
    private static func createPostRequest(data: Data, toUrl url: String, headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        for (k,v) in RestServiceApi.headers {
            request.addValue(v, forHTTPHeaderField: k)
        }
        for (k,v) in headers {
            request.addValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = data
        request.addValue(ContentType.FORM.rawValue, forHTTPHeaderField: "Content-Type")
        #if DEBUG
        self.logRequestEx(request)
        #endif
        return request
    }
    
    // MARK: - Logs

    public static var logs = [String]()
    public static var logCallback: (()->())?

    /// Prints given request URL, Method and body
    ///
    /// - Parameters:
    ///   - request: URLRequest to log
    public static func logRequestEx(_ request: URLRequest) {
        // Log request URL
        var info = "url"
        if let m = request.httpMethod { info = m }
        let hash = "[H\(request.hashValue)]"
        var logMessage = "\(Date())"
        logMessage += "[REQUEST]\(hash)\n curl -X \(info) \"\(request.url!.absoluteString)\""
        
        // log body if set
        if let body = request.httpBody, let bodyAsString = String(data: body, encoding: .utf8) {
            logMessage += "\\\n\t -d '\(bodyAsString.replace("\n", withString: "\\\n"))'"
        }
        for (k,v) in request.allHTTPHeaderFields ?? [:] {
            logMessage += "\\\n\t -H \"\(k): \(v.replace("\"", withString: "\\\""))\""
        }
        print(logMessage)
        logs.append(logMessage)
        logCallback?()
    }
    
    /// Prints given response object.
    ///
    /// - Parameters:
    ///   - object: related object
    ///   - request: the request
    ///   - response: the response
    public static func logResponseEx(_ object: AnyObject?, forRequest request: URLRequest, response: URLResponse?) {
        let hash = "[H\(request.hashValue)]"
        var info: String = "\(Date())<----------------------------------------------------------[RESPONSE]\(hash):\n"
        if let response = response as? HTTPURLResponse {
            info += "HTTP \(response.statusCode); headers:\n"
            for (k,v) in response.allHeaderFields {
                info += "\t\(k): \(v)\n"
            }
        }
        else {
            info += "<no response> "
        }
        if let o: AnyObject = object {
            if let data = o as? Data {
                let json = try? JSON(data: data, options: JSONSerialization.ReadingOptions.allowFragments)
                if let json = json {
                    info += "\(json)"
                }
                else {
                    info += "Data[length=\(data.count)]"
                    if data.count < 10000 {
                        info += "\n" + (String(data: data, encoding: .utf8) ?? "")
                    }
                }
            }
            else {
                info += String(describing: o)
            }
        }
        else {
            info += "<null response>"
        }
        print(info)
        logs.append(info)
        logCallback?()
    }
}

extension Data {
    public init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
}

extension String {
    
    public init(base64Encoded: String) {
        let decodedData = Data(base64Encoded: base64Encoded)!
        self.init(data: decodedData, encoding: .utf8)!
    }
}

extension SignedReport {
    
    func toString() -> String {
        let data = try! report.serializedData()
        return String(data: data.base64EncodedData(), encoding: .utf8)!
    }
}
