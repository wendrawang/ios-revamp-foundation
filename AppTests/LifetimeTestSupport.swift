import XCTest

final class WeakReference<Object: AnyObject> {
    weak var value: Object?

    // Menyimpan dependency yang diinjeksi dan menyiapkan state milik instance.
    init(_ value: Object?) {
        self.value = value
    }
}

// Memastikan object tidak lagi diretain setelah scope autorelease selesai.
func assertDeallocated<Object: AnyObject>(
    _ makeObject: () -> Object,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let weakObject = WeakReference<Object>(nil)
    autoreleasepool {
        let object = makeObject()
        weakObject.value = object
    }
    XCTAssertNil(weakObject.value, "Expected object to deallocate", file: file, line: line)
}
