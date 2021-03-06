// The MIT License (MIT)
//
// Copyright (c) 2015-2016 Qvik (www.qvik.fi)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest

/// Example "remote service" used for testing
class RemoteService {
    let remoteImpl: BaseRemoteService
    let baseUrl = "http://www.site.com"

    func list(callback: ((RemoteResponse) -> Void)) {
        let url = "\(baseUrl)/list"

        remoteImpl.request(.GET, url, parameters: nil, callback: callback)
    }

    func update(name name: String, age: Int, married: Bool, callback: ((RemoteResponse) -> Void)) {
        let url = "\(baseUrl)/update"

        let params: [String: AnyObject] = ["name": name, "age": age, "married": married]

        remoteImpl.request(.POST, url, parameters: params, callback: callback)
    }

    init(remoteImpl: BaseRemoteService) {
        self.remoteImpl = remoteImpl
    }
}

class MockRemoteServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()

        QvikNetwork.logLevel = .Verbose
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSuccess() {
        let remoteService = RemoteService(remoteImpl: MockRemoteService())

        let expectation = expectationWithDescription("success")

        remoteService.list { response in
            if response.success {
                expectation.fulfill()
            }
        }

        waitForExpectationsWithTimeout(1.0, handler: nil)
    }

    func testFailure() {
        let mockService = MockRemoteService()

        // Set every request to fail always
        mockService.failureProbability = 1.0

        let remoteService = RemoteService(remoteImpl: mockService)

        let expectation = expectationWithDescription("failure")

        remoteService.list { response in
            // The request must fail in order for the test to pass
            if !response.success {
                expectation.fulfill()
            }
        }

        waitForExpectationsWithTimeout(1.0, handler: nil)
    }

    func testSimplePathMapping() {
        let mockService = MockRemoteService()

        // Create a precondition that /update always fails
        mockService.addOperationMappingForPath("/update", mapping: (failureProbability: 1.0, params: nil, successResponse: ["status": "ok"], failureResponse: ["status": "failed"], failureError: .ServerError))
        let remoteService = RemoteService(remoteImpl: mockService)

        let listMustSucceed = expectationWithDescription("listMustSucceed")
        let updateMustFail = expectationWithDescription("updateMustFail")

        remoteService.list { response in
            if response.success {
                listMustSucceed.fulfill()
            }
        }

        remoteService.update(name: "Gary", age: 44, married: true) { response in
            if !response.success {
                updateMustFail.fulfill()
            }
        }

        waitForExpectationsWithTimeout(1.0, handler: nil)
    }

    func testPathAndParamMapping() {
        let mockService = MockRemoteService()

        // Create a precondition that /update always fails if params age = 17, married = true are set
        mockService.addOperationMappingForPath("/update", mapping: (failureProbability: 1.0, params: ["age": 17, "married": true], successResponse: ["status": "ok"], failureResponse: ["status": "failed"], failureError: .ServerError))

        // Set default success response content
        mockService.successResponse = ["status": "ok"]

        let remoteService = RemoteService(remoteImpl: mockService)

        let mustSucceed = expectationWithDescription("Must succeed with these params")
        let mustFail = expectationWithDescription("Must fail with these params")

        // Start a request that should succeed
        remoteService.update(name: "Leslie", age: 18, married: true) { response in
            if response.success {
                // Also check that proper success response content is in place
                if let status = response.parsedJson?["status"] as? String where status == "ok" {
                    mustSucceed.fulfill()
                }
            }
        }

        // Start a request that should fail
        remoteService.update(name: "Leslie", age: 17, married: true) { response in
            if !response.success {
                // Also check that proper failure content is in place
                if let status = response.parsedJson?["status"] as? String where status == "failed" {
                    mustFail.fulfill()
                }
            }
        }

        waitForExpectationsWithTimeout(1.0, handler: nil)
    }
}
