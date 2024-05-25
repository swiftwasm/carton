#if os(WASI)
import WASILibc
typealias FILEPointer = OpaquePointer
#else
import Darwin
typealias FILEPointer = UnsafeMutablePointer<FILE>
#endif

func fputs(_ string: String, file: FILEPointer) {
    _ = string.withCString { (cstr) in
        fputs(cstr, file)
    }
}

fputs("hello stdout\n", file: stdout)
fputs("hello stderr\n", file: stderr)
