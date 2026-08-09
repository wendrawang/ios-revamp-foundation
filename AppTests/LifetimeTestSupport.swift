import XCTest

final class WeakReference<Object: AnyObject> {
    weak var value: Object?

    init(_ value: Object?) {
        self.value = value
    }
}

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
