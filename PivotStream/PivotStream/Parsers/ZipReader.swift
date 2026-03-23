import Foundation
import zlib

enum ZipError: Error {
    case invalidFormat
    case unsupportedCompression
    case decompressionFailed
    case fileNotFound(String)
}

struct ZipReader {
    private let data: Data

    init(url: URL) throws {
        data = try Data(contentsOf: url, options: .mappedIfSafe)
    }

    // Returns all entries as filename -> data
    nonisolated func readAll() throws -> [String: Data] {
        let entries = try centralDirectoryEntries()
        var result: [String: Data] = [:]
        for entry in entries where !entry.name.hasSuffix("/") {
            result[entry.name] = try extractData(entry: entry)
        }
        return result
    }

    nonisolated func readFile(_ name: String) throws -> Data {
        let entries = try centralDirectoryEntries()
        guard let entry = entries.first(where: { $0.name == name }) else {
            throw ZipError.fileNotFound(name)
        }
        return try extractData(entry: entry)
    }

    nonisolated func fileNames() throws -> [String] {
        return try centralDirectoryEntries().map { $0.name }
    }

    // MARK: - Internal

    private struct CDEntry {
        let name: String
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let localHeaderOffset: UInt32
    }

    private struct EOCDRecord {
        let centralDirOffset: UInt32
        let numEntries: UInt16
    }

    nonisolated private func findEOCD() -> Int? {
        let sig: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        let minSize = 22
        let maxComment = 65535
        let searchStart = max(0, data.count - minSize - maxComment)

        var i = data.count - minSize
        while i >= searchStart {
            if data[i] == sig[0] && data[i+1] == sig[1] &&
               data[i+2] == sig[2] && data[i+3] == sig[3] {
                return i
            }
            i -= 1
        }
        return nil
    }

    nonisolated private func parseEOCD(at offset: Int) -> EOCDRecord {
        let numEntries = data.u16(at: offset + 10)
        let cdOffset   = data.u32(at: offset + 16)
        return EOCDRecord(centralDirOffset: cdOffset, numEntries: numEntries)
    }

    nonisolated private func centralDirectoryEntries() throws -> [CDEntry] {
        guard let eocdOffset = findEOCD() else { throw ZipError.invalidFormat }
        let eocd = parseEOCD(at: eocdOffset)

        var entries: [CDEntry] = []
        var offset = Int(eocd.centralDirOffset)

        for _ in 0..<eocd.numEntries {
            guard data.u32(at: offset) == 0x02014b50 else { throw ZipError.invalidFormat }

            let compressionMethod = data.u16(at: offset + 10)
            let compressedSize    = data.u32(at: offset + 20)
            let uncompressedSize  = data.u32(at: offset + 24)
            let filenameLen       = Int(data.u16(at: offset + 28))
            let extraLen          = Int(data.u16(at: offset + 30))
            let commentLen        = Int(data.u16(at: offset + 32))
            let localHeaderOffset = data.u32(at: offset + 42)

            let nameBytes = data[(offset + 46)..<(offset + 46 + filenameLen)]
            let name = String(bytes: nameBytes, encoding: .utf8) ?? String(bytes: nameBytes, encoding: .isoLatin1) ?? ""

            entries.append(CDEntry(
                name: name,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            ))

            offset += 46 + filenameLen + extraLen + commentLen
        }
        return entries
    }

    nonisolated private func extractData(entry: CDEntry) throws -> Data {
        let localOffset = Int(entry.localHeaderOffset)
        guard data.u32(at: localOffset) == 0x04034b50 else { throw ZipError.invalidFormat }

        let filenameLen = Int(data.u16(at: localOffset + 26))
        let extraLen    = Int(data.u16(at: localOffset + 28))
        let dataOffset  = localOffset + 30 + filenameLen + extraLen
        let dataEnd     = dataOffset + Int(entry.compressedSize)

        guard dataEnd <= data.count else { throw ZipError.invalidFormat }
        let compressed = data[dataOffset..<dataEnd]

        switch entry.compressionMethod {
        case 0:
            return Data(compressed)
        case 8:
            return try inflateRaw(Data(compressed), expectedSize: Int(entry.uncompressedSize))
        default:
            throw ZipError.unsupportedCompression
        }
    }

    nonisolated private func inflateRaw(_ compressed: Data, expectedSize: Int) throws -> Data {
        let outSize = max(expectedSize, 1)
        let outBuffer = UnsafeMutablePointer<Bytef>.allocate(capacity: outSize)
        defer { outBuffer.deallocate() }

        var actualSize: Int = 0
        var status: Int32 = Z_STREAM_ERROR

        compressed.withUnsafeBytes { inBuf in
            guard let inBase = inBuf.bindMemory(to: Bytef.self).baseAddress else { return }
            var stream = z_stream()
            stream.next_in   = UnsafeMutablePointer<Bytef>(mutating: inBase)
            stream.avail_in  = uInt(compressed.count)
            stream.next_out  = outBuffer
            stream.avail_out = uInt(outSize)

            guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                return
            }
            status = inflate(&stream, Z_FINISH)
            actualSize = Int(stream.total_out)
            inflateEnd(&stream)
        }

        guard status == Z_STREAM_END || status == Z_OK else { throw ZipError.decompressionFailed }
        return Data(bytes: outBuffer, count: actualSize)
    }
}

// MARK: - Data helpers

private extension Data {
    func u16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    func u32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
