//
// APIClientType.swift
//
// Copyright (c) 2016 Netguru Sp. z o.o. All rights reserved.
// Licensed under the MIT License.
//

/// Describes a type that is capable of sending image analysis requests
/// to Google Cloud Vision API.
public protocol APIClientType {

	/// Sends request to Google Cloud Vision API.
	///
	/// - Parameters:
	///     - request: An `AnnotationRequest` describing image type and
	///       detection features.
	///     - completion: A closure with `PicguardResult<AnnotationResponse>`,
	///       called when response comes from Google Cloud Vision API.
	func perform(request request: AnnotationRequest, completion: (PicguardResult<AnnotationResponse>) -> Void)
}
