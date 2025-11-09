import Foundation
import CoreGraphics

class STLExporter {
    struct Triangle {
        let normal: Vector3
        let v1: Vector3
        let v2: Vector3
        let v3: Vector3
    }

    struct Vector3 {
        let x: Float
        let y: Float
        let z: Float

        static var zero: Vector3 { Vector3(x: 0, y: 0, z: 0) }

        static func +(lhs: Vector3, rhs: Vector3) -> Vector3 {
            return Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
        }

        static func -(lhs: Vector3, rhs: Vector3) -> Vector3 {
            return Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
        }

        static func *(lhs: Vector3, rhs: Float) -> Vector3 {
            return Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
        }

        func cross(_ other: Vector3) -> Vector3 {
            return Vector3(
                x: y * other.z - z * other.y,
                y: z * other.x - x * other.z,
                z: x * other.y - y * other.x
            )
        }

        func normalized() -> Vector3 {
            let length = sqrt(x * x + y * y + z * z)
            guard length > 0 else { return self }
            return Vector3(x: x / length, y: y / length, z: z / length)
        }
    }

    func exportProject(_ project: Project, scale: Double) -> Data? {
        var triangles: [Triangle] = []

        guard let bounds = project.workspaceBounds else { return nil }

        let settings = project.traySettings
        let margin = settings.edgeMargin

        // Tray dimensions
        let trayWidth = Float((bounds.width + 2 * margin) * scale)
        let trayHeight = Float((bounds.height + 2 * margin) * scale)
        let trayThickness = Float(settings.trayThickness)

        // Create tray base
        let baseTriangles = createBox(
            width: trayWidth,
            height: trayThickness,
            depth: trayHeight
        )
        triangles.append(contentsOf: baseTriangles)

        // Subtract pockets
        for tool in project.tools where tool.enabled {
            let pocketTriangles = createPocket(
                contour: tool.offsetContour,
                depth: Float(tool.effectiveDepth),
                baseZ: Float(trayThickness),
                scale: Float(scale),
                offset: Vector3(x: Float(margin * scale), y: 0, z: Float(margin * scale))
            )

            triangles.append(contentsOf: pocketTriangles)
        }

        // Add chamfers if enabled
        if settings.chamferSize > 0 {
            // Simplified: skip chamfers for now (complex geometry)
        }

        // Generate binary STL
        return generateBinarySTL(triangles: triangles, name: project.name)
    }

    private func createBox(width: Float, height: Float, depth: Float) -> [Triangle] {
        var triangles: [Triangle] = []

        let v000 = Vector3(x: 0, y: 0, z: 0)
        let v001 = Vector3(x: 0, y: 0, z: depth)
        let v010 = Vector3(x: 0, y: height, z: 0)
        let v011 = Vector3(x: 0, y: height, z: depth)
        let v100 = Vector3(x: width, y: 0, z: 0)
        let v101 = Vector3(x: width, y: 0, z: depth)
        let v110 = Vector3(x: width, y: height, z: 0)
        let v111 = Vector3(x: width, y: height, z: depth)

        // Bottom face
        triangles.append(contentsOf: createQuad(v000, v100, v101, v001, normal: Vector3(x: 0, y: -1, z: 0)))

        // Top face
        triangles.append(contentsOf: createQuad(v010, v011, v111, v110, normal: Vector3(x: 0, y: 1, z: 0)))

        // Front face
        triangles.append(contentsOf: createQuad(v000, v001, v011, v010, normal: Vector3(x: -1, y: 0, z: 0)))

        // Back face
        triangles.append(contentsOf: createQuad(v100, v110, v111, v101, normal: Vector3(x: 1, y: 0, z: 0)))

        // Left face
        triangles.append(contentsOf: createQuad(v000, v010, v110, v100, normal: Vector3(x: 0, y: 0, z: -1)))

        // Right face
        triangles.append(contentsOf: createQuad(v001, v101, v111, v011, normal: Vector3(x: 0, y: 0, z: 1)))

        return triangles
    }

    private func createQuad(_ v1: Vector3, _ v2: Vector3, _ v3: Vector3, _ v4: Vector3, normal: Vector3) -> [Triangle] {
        return [
            Triangle(normal: normal, v1: v1, v2: v2, v3: v3),
            Triangle(normal: normal, v1: v1, v2: v3, v3: v4)
        ]
    }

    private func createPocket(contour: [CGPoint], depth: Float, baseZ: Float, scale: Float, offset: Vector3) -> [Triangle] {
        var triangles: [Triangle] = []

        guard contour.count >= 3 else { return triangles }

        // Convert contour to 3D vertices
        var topVertices: [Vector3] = []
        var bottomVertices: [Vector3] = []

        for point in contour {
            let x = Float(point.x) * scale + offset.x
            let z = Float(point.y) * scale + offset.z

            topVertices.append(Vector3(x: x, y: baseZ, z: z))
            bottomVertices.append(Vector3(x: x, y: baseZ - depth, z: z))
        }

        // Create pocket bottom (triangulate polygon)
        let bottomTriangles = triangulatePolygon(vertices: bottomVertices, normal: Vector3(x: 0, y: -1, z: 0))
        triangles.append(contentsOf: bottomTriangles)

        // Create pocket walls
        for i in 0..<contour.count {
            let next = (i + 1) % contour.count

            let t1 = topVertices[i]
            let t2 = topVertices[next]
            let b1 = bottomVertices[i]
            let b2 = bottomVertices[next]

            // Calculate normal
            let edge1 = t2 - t1
            let edge2 = b1 - t1
            let normal = edge1.cross(edge2).normalized()

            // Two triangles for wall quad
            triangles.append(Triangle(normal: normal, v1: t1, v2: b1, v3: b2))
            triangles.append(Triangle(normal: normal, v1: t1, v2: b2, v3: t2))
        }

        return triangles
    }

    private func triangulatePolygon(vertices: [Vector3], normal: Vector3) -> [Triangle] {
        var triangles: [Triangle] = []

        guard vertices.count >= 3 else { return triangles }

        // Simple fan triangulation from first vertex
        let v0 = vertices[0]

        for i in 1..<(vertices.count - 1) {
            let v1 = vertices[i]
            let v2 = vertices[i + 1]

            triangles.append(Triangle(normal: normal, v1: v0, v2: v1, v3: v2))
        }

        return triangles
    }

    private func generateBinarySTL(triangles: [Triangle], name: String) -> Data {
        var data = Data()

        // Header (80 bytes)
        var header = name.padding(toLength: 80, withPad: " ", startingAt: 0)
        data.append(header.data(using: .ascii)!)

        // Number of triangles (4 bytes, little endian)
        var count = UInt32(triangles.count).littleEndian
        data.append(Data(bytes: &count, count: 4))

        // Triangles
        for triangle in triangles {
            // Normal (3 floats)
            var nx = triangle.normal.x
            var ny = triangle.normal.y
            var nz = triangle.normal.z
            data.append(Data(bytes: &nx, count: 4))
            data.append(Data(bytes: &ny, count: 4))
            data.append(Data(bytes: &nz, count: 4))

            // Vertex 1
            var v1x = triangle.v1.x
            var v1y = triangle.v1.y
            var v1z = triangle.v1.z
            data.append(Data(bytes: &v1x, count: 4))
            data.append(Data(bytes: &v1y, count: 4))
            data.append(Data(bytes: &v1z, count: 4))

            // Vertex 2
            var v2x = triangle.v2.x
            var v2y = triangle.v2.y
            var v2z = triangle.v2.z
            data.append(Data(bytes: &v2x, count: 4))
            data.append(Data(bytes: &v2y, count: 4))
            data.append(Data(bytes: &v2z, count: 4))

            // Vertex 3
            var v3x = triangle.v3.x
            var v3y = triangle.v3.y
            var v3z = triangle.v3.z
            data.append(Data(bytes: &v3x, count: 4))
            data.append(Data(bytes: &v3y, count: 4))
            data.append(Data(bytes: &v3z, count: 4))

            // Attribute byte count (2 bytes)
            var attr: UInt16 = 0
            data.append(Data(bytes: &attr, count: 2))
        }

        return data
    }

    func saveToFile(_ data: Data, filename: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving STL file: \(error)")
            return nil
        }
    }
}
