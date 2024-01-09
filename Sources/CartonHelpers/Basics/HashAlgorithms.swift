/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(CryptoKit)
  import CryptoKit
#endif

public protocol HashAlgorithm: Sendable {

  /// Hashes the input bytes, returning the digest.
  ///
  /// - Parameters:
  ///   - bytes: The input bytes.
  /// - Returns: The output digest.
  func hash(_ bytes: ByteString) -> ByteString
}

extension HashAlgorithm {
  public func hash(_ string: String) -> ByteString {
    hash(ByteString([UInt8](string.utf8)))
  }
}

/// SHA-256 implementation from Secure Hash Algorithm 2 (SHA-2) set of
/// cryptographic hash functions (FIPS PUB 180-2).
///  Uses CryptoKit where available
public struct SHA256: HashAlgorithm, Sendable {
  private let underlying: HashAlgorithm

  public init() {
    #if canImport(CryptoKit)
      if #available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) {
        self.underlying = _CryptoKitSHA256()
      } else {
        self.underlying = InternalSHA256()
      }
    #else
      self.underlying = InternalSHA256()
    #endif
  }
  public func hash(_ bytes: ByteString) -> ByteString {
    self.underlying.hash(bytes)
  }
}

/// SHA-256 implementation from Secure Hash Algorithm 2 (SHA-2) set of
/// cryptographic hash functions (FIPS PUB 180-2).
struct InternalSHA256: HashAlgorithm {
  /// The length of the output digest (in bits).
  private static let digestLength = 256

  /// The size of each blocks (in bits).
  private static let blockBitSize = 512

  /// The initial hash value.
  private static let initalHashValue: [UInt32] = [
    0x6a09_e667, 0xbb67_ae85, 0x3c6e_f372, 0xa54f_f53a, 0x510e_527f, 0x9b05_688c, 0x1f83_d9ab,
    0x5be0_cd19,
  ]

  /// The constants in the algorithm (K).
  private static let konstants: [UInt32] = [
    0x428a_2f98, 0x7137_4491, 0xb5c0_fbcf, 0xe9b5_dba5, 0x3956_c25b, 0x59f1_11f1, 0x923f_82a4,
    0xab1c_5ed5,
    0xd807_aa98, 0x1283_5b01, 0x2431_85be, 0x550c_7dc3, 0x72be_5d74, 0x80de_b1fe, 0x9bdc_06a7,
    0xc19b_f174,
    0xe49b_69c1, 0xefbe_4786, 0x0fc1_9dc6, 0x240c_a1cc, 0x2de9_2c6f, 0x4a74_84aa, 0x5cb0_a9dc,
    0x76f9_88da,
    0x983e_5152, 0xa831_c66d, 0xb003_27c8, 0xbf59_7fc7, 0xc6e0_0bf3, 0xd5a7_9147, 0x06ca_6351,
    0x1429_2967,
    0x27b7_0a85, 0x2e1b_2138, 0x4d2c_6dfc, 0x5338_0d13, 0x650a_7354, 0x766a_0abb, 0x81c2_c92e,
    0x9272_2c85,
    0xa2bf_e8a1, 0xa81a_664b, 0xc24b_8b70, 0xc76c_51a3, 0xd192_e819, 0xd699_0624, 0xf40e_3585,
    0x106a_a070,
    0x19a4_c116, 0x1e37_6c08, 0x2748_774c, 0x34b0_bcb5, 0x391c_0cb3, 0x4ed8_aa4a, 0x5b9c_ca4f,
    0x682e_6ff3,
    0x748f_82ee, 0x78a5_636f, 0x84c8_7814, 0x8cc7_0208, 0x90be_fffa, 0xa450_6ceb, 0xbef9_a3f7,
    0xc671_78f2,
  ]

  public init() {
  }

  public func hash(_ bytes: ByteString) -> ByteString {
    var input = bytes.contents

    // Pad the input.
    pad(&input)

    // Break the input into N 512-bit blocks.
    let messageBlocks = input.blocks(size: Self.blockBitSize / 8)

    /// The hash that is being computed.
    var hash = Self.initalHashValue

    // Process each block.
    for block in messageBlocks {
      process(block, hash: &hash)
    }

    // Finally, compute the result.
    var result = [UInt8](repeating: 0, count: Self.digestLength / 8)
    for (idx, element) in hash.enumerated() {
      let pos = idx * 4
      result[pos + 0] = UInt8((element >> 24) & 0xff)
      result[pos + 1] = UInt8((element >> 16) & 0xff)
      result[pos + 2] = UInt8((element >> 8) & 0xff)
      result[pos + 3] = UInt8(element & 0xff)
    }

    return ByteString(result)
  }

  /// Process and compute hash from a block.
  private func process(_ block: ArraySlice<UInt8>, hash: inout [UInt32]) {

    // Compute message schedule.
    var W = [UInt32](repeating: 0, count: Self.konstants.count)
    for t in 0..<W.count {
      switch t {
      case 0...15:
        let index = block.startIndex.advanced(by: t * 4)
        // Put 4 bytes in each message.
        W[t] = UInt32(block[index + 0]) << 24
        W[t] |= UInt32(block[index + 1]) << 16
        W[t] |= UInt32(block[index + 2]) << 8
        W[t] |= UInt32(block[index + 3])
      default:
        let σ1 = W[t - 2].rotateRight(by: 17) ^ W[t - 2].rotateRight(by: 19) ^ (W[t - 2] >> 10)
        let σ0 = W[t - 15].rotateRight(by: 7) ^ W[t - 15].rotateRight(by: 18) ^ (W[t - 15] >> 3)
        W[t] = σ1 &+ W[t - 7] &+ σ0 &+ W[t - 16]
      }
    }

    var a = hash[0]
    var b = hash[1]
    var c = hash[2]
    var d = hash[3]
    var e = hash[4]
    var f = hash[5]
    var g = hash[6]
    var h = hash[7]

    // Run the main algorithm.
    for t in 0..<Self.konstants.count {
      let Σ1 = e.rotateRight(by: 6) ^ e.rotateRight(by: 11) ^ e.rotateRight(by: 25)
      let ch = (e & f) ^ (~e & g)
      let t1 = h &+ Σ1 &+ ch &+ Self.konstants[t] &+ W[t]

      let Σ0 = a.rotateRight(by: 2) ^ a.rotateRight(by: 13) ^ a.rotateRight(by: 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let t2 = Σ0 &+ maj

      h = g
      g = f
      f = e
      e = d &+ t1
      d = c
      c = b
      b = a
      a = t1 &+ t2
    }

    hash[0] = a &+ hash[0]
    hash[1] = b &+ hash[1]
    hash[2] = c &+ hash[2]
    hash[3] = d &+ hash[3]
    hash[4] = e &+ hash[4]
    hash[5] = f &+ hash[5]
    hash[6] = g &+ hash[6]
    hash[7] = h &+ hash[7]
  }

  /// Pad the given byte array to be a multiple of 512 bits.
  private func pad(_ input: inout [UInt8]) {
    // Find the bit count of input.
    let inputBitLength = input.count * 8

    // Append the bit 1 at end of input.
    input.append(0x80)

    // Find the number of bits we need to append.
    //
    // inputBitLength + 1 + bitsToAppend ≡ 448 mod 512
    let mod = inputBitLength % 512
    let bitsToAppend = mod < 448 ? 448 - 1 - mod : 512 + 448 - mod - 1

    // We already appended first 7 bits with 0x80 above.
    input += [UInt8](repeating: 0, count: (bitsToAppend - 7) / 8)

    // We need to append 64 bits of input length.
    for byte in UInt64(inputBitLength).toByteArray().lazy.reversed() {
      input.append(byte)
    }
    assert((input.count * 8) % 512 == 0, "Expected padded length to be 512.")
  }
}

#if canImport(CryptoKit)
  @available(*, deprecated, message: "use SHA256 which abstract over platform differences")
  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  public struct CryptoKitSHA256: HashAlgorithm, Sendable {
    let underlying = _CryptoKitSHA256()
    public init() {}
    public func hash(_ bytes: ByteString) -> ByteString {
      self.underlying.hash(bytes)
    }
  }

  /// Wraps CryptoKit.SHA256 to provide a HashAlgorithm conformance to it.
  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  struct _CryptoKitSHA256: HashAlgorithm {
    public init() {
    }
    public func hash(_ bytes: ByteString) -> ByteString {
      return bytes.withData { data in
        let digest = CryptoKit.SHA256.hash(data: data)
        return ByteString(digest)
      }
    }
  }
#endif

// MARK:- Helpers

extension UInt64 {
  /// Converts the 64 bit integer into an array of single byte integers.
  fileprivate func toByteArray() -> [UInt8] {
    var value = self.littleEndian
    return withUnsafeBytes(of: &value, Array.init)
  }
}

extension UInt32 {
  /// Rotates self by given amount.
  fileprivate func rotateRight(by amount: UInt32) -> UInt32 {
    return (self >> amount) | (self << (32 - amount))
  }
}

extension Array {
  /// Breaks the array into the given size.
  fileprivate func blocks(size: Int) -> AnyIterator<ArraySlice<Element>> {
    var currentIndex = startIndex
    return AnyIterator {
      if let nextIndex = self.index(currentIndex, offsetBy: size, limitedBy: self.endIndex) {
        defer { currentIndex = nextIndex }
        return self[currentIndex..<nextIndex]
      }
      return nil
    }
  }
}
