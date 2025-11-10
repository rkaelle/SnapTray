import Foundation
import CoreGraphics
import simd

struct Project: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var createdDate: Date
    var modifiedDate: Date

    // Captured data
    var capturedImage: Data?
    var depthMap: Data?
    var cameraTransform: matrix_float4x4?

    // Fiducial data
    var fiducials: [Fiducial]
    var workspaceBounds: CGRect?
    var pixelToMMScale: Double?

    // Detected tools
    var tools: [Tool]

    // Tray settings
    var traySettings: TraySettings

    init(name: String = "Untitled Project") {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.fiducials = []
        self.tools = []
        self.traySettings = TraySettings()
    }

    // Custom Codable implementation to skip cameraTransform (matrix_float4x4 doesn't conform to Codable)
    enum CodingKeys: String, CodingKey {
        case id, name, createdDate, modifiedDate
        case capturedImage, depthMap
        case fiducials, workspaceBounds, pixelToMMScale
        case tools, traySettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        capturedImage = try container.decodeIfPresent(Data.self, forKey: .capturedImage)
        depthMap = try container.decodeIfPresent(Data.self, forKey: .depthMap)
        fiducials = try container.decode([Fiducial].self, forKey: .fiducials)
        workspaceBounds = try container.decodeIfPresent(CGRect.self, forKey: .workspaceBounds)
        pixelToMMScale = try container.decodeIfPresent(Double.self, forKey: .pixelToMMScale)
        tools = try container.decode([Tool].self, forKey: .tools)
        traySettings = try container.decode(TraySettings.self, forKey: .traySettings)
        cameraTransform = nil  // Not persisted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encodeIfPresent(capturedImage, forKey: .capturedImage)
        try container.encodeIfPresent(depthMap, forKey: .depthMap)
        try container.encode(fiducials, forKey: .fiducials)
        try container.encodeIfPresent(workspaceBounds, forKey: .workspaceBounds)
        try container.encodeIfPresent(pixelToMMScale, forKey: .pixelToMMScale)
        try container.encode(tools, forKey: .tools)
        try container.encode(traySettings, forKey: .traySettings)
        // cameraTransform is not encoded (matrix_float4x4 doesn't conform to Codable)
    }

    // Hashable conformance based on unique id
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Fiducial: Codable, Identifiable {
    let id: UUID
    var position: CGPoint
    var markerID: Int?
    var coinDetected: Bool
    var coinRadius: Double?

    init(position: CGPoint, markerID: Int? = nil) {
        self.id = UUID()
        self.position = position
        self.markerID = markerID
        self.coinDetected = false
    }
}

struct Tool: Codable, Identifiable {
    let id: UUID
    var label: String
    var contour: [CGPoint]
    var simplifiedContour: [CGPoint]
    var offsetContour: [CGPoint]
    var boundingBox: CGRect
    var area: Double
    var maxDepth: Double
    var depthOverride: Double?
    var hasFingerNotch: Bool
    var fingerNotch: FingerNotch?
    var enabled: Bool

    init(contour: [CGPoint], maxDepth: Double) {
        self.id = UUID()
        self.label = ""
        self.contour = contour
        self.simplifiedContour = contour
        self.offsetContour = contour
        self.boundingBox = Tool.calculateBoundingBox(for: contour)
        self.area = Tool.calculateArea(for: contour)
        self.maxDepth = maxDepth
        self.hasFingerNotch = true
        self.enabled = true
    }

    static func calculateBoundingBox(for points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func calculateArea(for points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }

        var area: Double = 0
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += Double(points[i].x * points[j].y)
            area -= Double(points[j].x * points[i].y)
        }
        return abs(area) / 2.0
    }

    var effectiveDepth: Double {
        return depthOverride ?? maxDepth
    }
}

struct FingerNotch: Codable {
    var position: CGPoint
    var radius: Double
    var edgeIndex: Int
    var normalizedPosition: Double  // 0.0 to 1.0 along the edge

    init(position: CGPoint, radius: Double, edgeIndex: Int, normalizedPosition: Double = 0.35) {
        self.position = position
        self.radius = radius
        self.edgeIndex = edgeIndex
        self.normalizedPosition = normalizedPosition
    }
}

struct TraySettings: Codable {
    var material: MaterialType
    var trayThickness: Double
    var edgeMargin: Double
    var xyInterference: Double
    var zOffset: Double
    var chamferSize: Double
    var addDrainHoles: Bool
    var drainHoleDiameter: Double
    var addMagnetCavities: Bool
    var magnetDiameter: Double
    var magnetDepth: Double
    var embossLabels: Bool
    var labelHeight: Double

    init() {
        self.material = .pla
        self.trayThickness = 12.0
        self.edgeMargin = 10.0
        self.xyInterference = 0.25
        self.zOffset = 0.0
        self.chamferSize = 1.0
        self.addDrainHoles = false
        self.drainHoleDiameter = 2.5
        self.addMagnetCavities = false
        self.magnetDiameter = 6.0
        self.magnetDepth = 2.0
        self.embossLabels = true
        self.labelHeight = 0.5
    }
}

enum MaterialType: String, Codable, CaseIterable {
    case pla = "PLA"
    case petg = "PETG"
    case tpu = "TPU"
    case foam = "Foam"
    case custom = "Custom"

    var displayName: String {
        return self.rawValue
    }
}

struct MaterialPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var material: MaterialType
    var xyInterference: Double
    var zOffset: Double
    var kerfCompensation: Double

    init(name: String, material: MaterialType, xyInterference: Double, zOffset: Double, kerfCompensation: Double = 0.0) {
        self.id = UUID()
        self.name = name
        self.material = material
        self.xyInterference = xyInterference
        self.zOffset = zOffset
        self.kerfCompensation = kerfCompensation
    }

    static var defaults: [MaterialPreset] {
        return [
            MaterialPreset(name: "PLA (Snug)", material: .pla, xyInterference: 0.25, zOffset: 0.0),
            MaterialPreset(name: "PLA (Loose)", material: .pla, xyInterference: 0.15, zOffset: 0.5),
            MaterialPreset(name: "PETG (Snug)", material: .petg, xyInterference: 0.30, zOffset: 0.0),
            MaterialPreset(name: "PETG (Loose)", material: .petg, xyInterference: 0.20, zOffset: 0.5),
            MaterialPreset(name: "TPU", material: .tpu, xyInterference: 0.40, zOffset: 0.0),
            MaterialPreset(name: "Foam (Laser)", material: .foam, xyInterference: -0.30, zOffset: 0.0, kerfCompensation: 0.15),
            MaterialPreset(name: "Foam (CNC)", material: .foam, xyInterference: -0.20, zOffset: 0.0, kerfCompensation: 0.0)
        ]
    }
}

struct ToleranceSettings: Codable {
    var xyInterference: Double
    var zOffset: Double
    var material: MaterialType
}
