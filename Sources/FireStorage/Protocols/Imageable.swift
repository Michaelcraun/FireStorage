//
//  File.swift
//  
//
//  Created by Michael Craun on 9/28/22.
//

import Foundation

public protocol Imageable: AnyObject {
    typealias ImageDeleteCompletion = (Error?) -> Void
    typealias ImageGetCompletion = (Data?, Error?) -> Void
    typealias ImagePutCompletion = (String?, Error?) -> Void
    
    var imageData: Data? { get set }
    
    func image(name: String, extension: String, completion: ImageGetCompletion?)
    func putImage(data: Data, name: String, extension: String, completion: ImagePutCompletion?)
    func removeImage(named name: String, extension: String, completion: ImageDeleteCompletion?)
}
