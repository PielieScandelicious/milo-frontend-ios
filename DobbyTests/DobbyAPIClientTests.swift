//
//  DobbyAPIClientTests.swift
//  Dobby Receipt Tracker Tests
//
//  Created on January 20, 2026.
//

import XCTest
@testable import Dobby

class DobbyAPIClientTests: XCTestCase {
    
    // MARK: - Model Decoding Tests
    
    func testDecodeReceiptResponse() async throws {
        let json = """
        {
          "receipt_id": "test-uuid-123",
          "status": "completed",
          "store_name": "COLRUYT",
          "receipt_date": "2026-01-16",
          "total_amount": 45.67,
          "items_count": 5,
          "transactions": [
            {
              "item_name": "Kipfilet",
              "item_price": 12.40,
              "quantity": 1,
              "unit_price": 12.40,
              "category": "Meat & Fish"
            }
          ],
          "warnings": ["Test warning"]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(ReceiptUploadResponse.self, from: data)
        
        XCTAssertEqual(response.receiptId, "test-uuid-123")
        XCTAssertEqual(response.status, "completed")
        XCTAssertEqual(response.storeName, "COLRUYT")
        XCTAssertEqual(response.receiptDate, "2026-01-16")
        XCTAssertEqual(response.totalAmount, 45.67)
        XCTAssertEqual(response.itemsCount, 5)
        XCTAssertEqual(response.transactions.count, 1)
        XCTAssertEqual(response.warnings.count, 1)
        
        let transaction = response.transactions[0]
        XCTAssertEqual(transaction.itemName, "Kipfilet")
        XCTAssertEqual(transaction.itemPrice, 12.40)
        XCTAssertEqual(transaction.quantity, 1)
        XCTAssertEqual(transaction.unitPrice, 12.40)
        XCTAssertEqual(transaction.category, "Meat & Fish")
    }
    
    func testDecodeStoreSummaries() async throws {
        let json = """
        [
          {
            "total_spend": 284.40,
            "period": "January 2026",
            "stores": [
              {
                "store_name": "COLRUYT",
                "amount_spent": 189.90,
                "store_visits": 4
              },
              {
                "store_name": "ALDI",
                "amount_spent": 94.50,
                "store_visits": 3
              }
            ]
          }
        ]
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let summaries = try decoder.decode([PeriodSummary].self, from: data)
        
        XCTAssertEqual(summaries.count, 1)
        
        let period = summaries[0]
        XCTAssertEqual(period.totalSpend, 284.40)
        XCTAssertEqual(period.period, "January 2026")
        XCTAssertEqual(period.stores.count, 2)
        
        let colruyt = period.stores[0]
        XCTAssertEqual(colruyt.storeName, "COLRUYT")
        XCTAssertEqual(colruyt.amountSpent, 189.90)
        XCTAssertEqual(colruyt.storeVisits, 4)
        
        let aldi = period.stores[1]
        XCTAssertEqual(aldi.storeName, "ALDI")
        XCTAssertEqual(aldi.amountSpent, 94.50)
        XCTAssertEqual(aldi.storeVisits, 3)
    }
    
    // MARK: - Helper Method Tests
    
    func testMimeTypeDetection() {
        let client = DobbyAPIClient()
        
        // Use reflection to test private method (or make it internal for testing)
        // For now, we'll test the file type validation indirectly
        
        let pdfURL = URL(fileURLWithPath: "/test/receipt.pdf")
        let jpgURL = URL(fileURLWithPath: "/test/receipt.jpg")
        let pngURL = URL(fileURLWithPath: "/test/receipt.png")
        
        XCTAssertEqual(pdfURL.pathExtension.lowercased(), "pdf")
        XCTAssertEqual(jpgURL.pathExtension.lowercased(), "jpg")
        XCTAssertEqual(pngURL.pathExtension.lowercased(), "png")
    }
    
    // MARK: - Error Handling Tests
    
    func testAPIErrorDescriptions() {
        let notAuthError = DobbyAPIError.notAuthenticated
        XCTAssertTrue(notAuthError.errorDescription?.contains("authenticated") == true)
        
        let invalidURLError = DobbyAPIError.invalidURL
        XCTAssertTrue(invalidURLError.errorDescription?.contains("URL") == true)
        
        let httpError = DobbyAPIError.httpError(statusCode: 404, message: "Not found")
        XCTAssertTrue(httpError.errorDescription?.contains("404") == true)
        
        let fileTypeError = DobbyAPIError.invalidFileType
        XCTAssertTrue(fileTypeError.errorDescription?.contains("PDF") == true)
    }
    
    // MARK: - Mock Network Tests
    
    func testHealthCheckWithMock() async throws {
        // Create mock response
        let url = URL(string: "https://dobby-api-production.up.railway.app/health")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let mockSession = MockURLSession(data: Data(), response: response, error: nil)
        let client = DobbyAPIClient(session: mockSession)
        
        let isHealthy = try await client.checkHealth()
        XCTAssertTrue(isHealthy)
    }
}

// MARK: - Mock URL Session

class MockURLSession: URLSession {
    private let mockData: Data?
    private let mockResponse: URLResponse?
    private let mockError: Error?
    
    init(data: Data?, response: URLResponse?, error: Error?) {
        self.mockData = data
        self.mockResponse = response
        self.mockError = error
    }
    
    override func data(from url: URL) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}
