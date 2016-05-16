//
// PicguardSpec.swift
//
// Copyright (c) 2016 Netguru Sp. z o.o. All rights reserved.
// Licensed under the MIT License.
//

import Nimble
import Quick
import Picguard

final class PicguardSpec: QuickSpec {

	override func spec() {

		describe("Picguard") {

			var mockClient: MockAPIClient!
			var sut: Picguard!

			beforeEach {
				mockClient = MockAPIClient()
				sut = Picguard(APIClient: mockClient)
			}

			afterEach {
				sut = nil
			}

			context("when initialized with API key") {

				var sut: Picguard!

				beforeEach {
					sut = Picguard(APIKey: "foo")
				}

				it("should have proper API client") {
					expect(sut.client.dynamicType == APIClient.self).to(beTruthy())
				}
			}

			describe("detect unsafe content") {

				var capturedResult: PicguardResult<Likelihood>!
				var image: UIImage!

				beforeEach {
					image = UIImage()
					sut.detectUnsafeContentLikelihood(image: .Image(UIImage())) { result in
						capturedResult = result
					}
				}

				it("perform proper request") {
					expect(mockClient.lastRequest).to(equal(try! AnnotationRequest(features: Set([.SafeSearch(maxResults: 1)]), image: .Image(image))))
				}

				context("when completion result has no safe search annotation") {

					beforeEach {
						mockClient.lastCompletion(
							PicguardResult<AnnotationResponse>.Success(
								AnnotationResponse.init(
									faceAnnotations: nil,
									labelAnnotations: nil,
									landmarkAnnotations: nil,
									logoAnnotations: nil,
									textAnnotations: nil,
									safeSearchAnnotation: nil,
									imagePropertiesAnnotation: nil
								)
							)
						)
					}

					it("should return result with unknown likelihood"){
						guard case .Success(let likelihood) = capturedResult! else {
							fail("failed to get value")
							return
						}
						expect(likelihood).to(equal(try! Likelihood(string: "UNKNOWN")))
					}

				}

				context("when completion result has safe search annotation") {

					beforeEach {
						mockClient.lastCompletion(
							PicguardResult<AnnotationResponse>.Success(
								AnnotationResponse.init(
									faceAnnotations: nil,
									labelAnnotations: nil,
									landmarkAnnotations: nil,
									logoAnnotations: nil,
									textAnnotations: nil,
									safeSearchAnnotation: SafeSearchAnnotation(
										adultContentLikelihood: .Likely,
										spoofContentLikelihood: .Likely,
										medicalContentLikelihood: .Likely,
										violentContentLikelihood: .Likely
									),
									imagePropertiesAnnotation: nil
								)
							)
						)
					}

					it("should return result with proper likelihood"){
						guard case .Success(let likelihood) = capturedResult! else {
							fail("failed to get value")
							return
						}
						expect(likelihood).to(equal(Likelihood.Likely))
					}

				}

				context("when completion result has an error") {

					beforeEach {
						mockClient.lastCompletion(PicguardResult<AnnotationResponse>.Error(APIClient.Error.NoResponse))
					}

					it("should return result with proper error"){
						guard
							case .Error(let error) = capturedResult!,
							case .NoResponse = error as! APIClient.Error
						else {
							fail("failed to get error")
							return
						}
					}
					
				}
				
			}

			describe("face presence likelihood detection") {

				var caughtRequest: AnnotationRequest? = nil
				var mockedResult: PicguardResult<AnnotationResponse>! = nil

				let picguard = Picguard(APIClient: MockAPIClient2 { request, completion in
					caughtRequest = request
					completion(mockedResult)
				})

				beforeEach {
					mockedResult = .Success(AnnotationResponse(
						faceAnnotations: nil,
						labelAnnotations: nil,
						landmarkAnnotations: nil,
						logoAnnotations: nil,
						textAnnotations: nil,
						safeSearchAnnotation: nil,
						imagePropertiesAnnotation: nil
					))
				}

				it("should send a correct request") {
					picguard.detectFacePresenceLikelihood(image: .Data(NSData()), completion: { _ in })
					let expectedRequest = try! AnnotationRequest(features: [.Face(maxResults: 1)], image: .Data(NSData()))
					expect(caughtRequest).toEventually(equal(expectedRequest))
				}

				context("given a response containing face annotation") {

					beforeEach {
						mockedResult = .Success(AnnotationResponse(
							faceAnnotations: [
								try! FaceAnnotation(
									boundingPolygon: BoundingPolygon(vertices: []),
									skinBoundingPolygon: BoundingPolygon(vertices: []),
									landmarks: [],
									rollAngle: 0,
									panAngle: 0,
									tiltAngle: 0,
									detectionConfidence: 0.75,
									landmarkingConfidence: 0.5,
									joyLikelihood: .Unknown,
									sorrowLikelihood: .Unknown,
									angerLikelihood: .Unknown,
									surpriseLikelihood: .Unknown,
									underExposedLikelihood: .Unknown,
									blurredLikelihood: .Unknown,
									headwearLikelihood: .Unknown
								)
							],
							labelAnnotations: nil,
							landmarkAnnotations: nil,
							logoAnnotations: nil,
							textAnnotations: nil,
							safeSearchAnnotation: nil,
							imagePropertiesAnnotation: nil
						))
					}

					it("should calculate a correct positive likelihood") {
						var caughtResult: PicguardResult<Likelihood>! = nil
						picguard.detectFacePresenceLikelihood(image: .Data(NSData()), completion: { caughtResult = $0 })
						expect(caughtResult).toEventually(beSuccessful(try! Likelihood(score: 0.75)))
					}

				}

				context("given a response containing no face annotations") {

					beforeEach {
						mockedResult = .Success(AnnotationResponse(
							faceAnnotations: [],
							labelAnnotations: nil,
							landmarkAnnotations: nil,
							logoAnnotations: nil,
							textAnnotations: nil,
							safeSearchAnnotation: nil,
							imagePropertiesAnnotation: nil
						))
					}

					it("should calculate unknown likelihood") {
						var caughtResult: PicguardResult<Likelihood>! = nil
						picguard.detectFacePresenceLikelihood(image: .Data(NSData()), completion: { caughtResult = $0 })
						expect(caughtResult).toEventually(beSuccessful(Likelihood.Unknown))
					}

				}

				context("given an erroneus response") {

					beforeEach {
						mockedResult = .Error(AnnotationError(code: 0, message: ""))
					}

					it("should forward an erroneus response") {
						var caughtResult: PicguardResult<Likelihood>! = nil
						picguard.detectFacePresenceLikelihood(image: .Data(NSData()), completion: { caughtResult = $0 })
						expect(caughtResult).toEventually(beErroneus())
					}

				}

			}

			describe("raw annotation") {

				var caughtRequest: AnnotationRequest? = nil
				var mockedResult: PicguardResult<AnnotationResponse>! = nil

				let picguard = Picguard(APIClient: MockAPIClient2 { request, completion in
					caughtRequest = request
					completion(mockedResult)
				})

				beforeEach {
					mockedResult = .Success(AnnotationResponse(
						faceAnnotations: nil,
						labelAnnotations: nil,
						landmarkAnnotations: nil,
						logoAnnotations: nil,
						textAnnotations: nil,
						safeSearchAnnotation: nil,
						imagePropertiesAnnotation: nil
					))
				}

				it("should send a correct request") {
					picguard.annotate(image: .Data(NSData()), features: [.Label(maxResults: 1)], completion: { _ in })
					let expectedRequest = try! AnnotationRequest(features: [.Label(maxResults: 1)], image: .Data(NSData()))
					expect(caughtRequest).toEventually(equal(expectedRequest))
				}

				context("given a successful response") {

					beforeEach {
						mockedResult = .Success(AnnotationResponse(
							faceAnnotations: nil,
							labelAnnotations: nil,
							landmarkAnnotations: nil,
							logoAnnotations: nil,
							textAnnotations: nil,
							safeSearchAnnotation: nil,
							imagePropertiesAnnotation: nil
						))
					}

					it("should calculate a correct positive likelihood") {
						var caughtResult: PicguardResult<AnnotationResponse>! = nil
						picguard.annotate(image: .Data(NSData()), features: [.Landmark(maxResults: 1)], completion: { caughtResult = $0 })
						expect(caughtResult).toEventually(beSuccessful(AnnotationResponse(
							faceAnnotations: nil,
							labelAnnotations: nil,
							landmarkAnnotations: nil,
							logoAnnotations: nil,
							textAnnotations: nil,
							safeSearchAnnotation: nil,
							imagePropertiesAnnotation: nil
						)))
					}

				}

				context("given an erroneus response") {

					beforeEach {
						mockedResult = .Error(AnnotationError(code: 0, message: ""))
					}

					it("should forward an erroneus response") {
						var caughtResult: PicguardResult<AnnotationResponse>! = nil
						picguard.annotate(image: .Data(NSData()), features: [.Text(maxResults: 1)], completion: { caughtResult = $0 })
						expect(caughtResult).toEventually(beErroneus())
					}

				}

			}

		}

	}

}

// MARK: -

private final class MockAPIClient: APIClientType {

	var lastRequest: AnnotationRequest!
	var lastCompletion: ((PicguardResult<AnnotationResponse>) -> Void)!

	func perform(request request: AnnotationRequest, completion: (PicguardResult<AnnotationResponse>) -> Void) {
		lastRequest = request
		lastCompletion = completion
	}

}

// MARK: -

private final class MockAPIClient2: APIClientType {

	private typealias PerformRequestClosureType = (AnnotationRequest, (PicguardResult<AnnotationResponse>) -> Void) -> Void

	private let performRequestClosure: PerformRequestClosureType

	private init(_ performRequestClosure: PerformRequestClosureType) {
		self.performRequestClosure = performRequestClosure
	}

	private func perform(request request: AnnotationRequest, completion: (PicguardResult<AnnotationResponse>) -> Void) {
		performRequestClosure(request, completion)
	}

}
