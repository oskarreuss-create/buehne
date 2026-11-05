import CoreGraphics
import Foundation
import IOSurface
import Metal
import QuartzCore

/// Presents libmpv's linear Display P3 frame on an EDR Metal layer.
/// 1.0 is SDR white. Values above 1.0 are the display headroom.
@MainActor
public final class EDRSurface {
    public let layer: CAMetalLayer
    public private(set) var presented = false
    public private(set) var presentedFrames = 0
    public let descriptionText: String
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private var pipeline: MTLRenderPipelineState?
    private var scale = Float(1)
    /// Visible part of the frame, normalised, origin top-left. The unit rect shows everything.
    public var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    public init() {
        let device = MTLCreateSystemDefaultDevice()!
        self.device = device
        self.queue = device.makeCommandQueue()!
        let metal = CAMetalLayer()
        metal.device = device
        metal.pixelFormat = .rgba16Float
        metal.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        metal.wantsExtendedDynamicRangeContent = true
        metal.isOpaque = true
        metal.framebufferOnly = true
        self.layer = metal
        let name = metal.colorspace?.name as String? ?? "nil"
        descriptionText = "format=rgba16Float edr=\(metal.wantsExtendedDynamicRangeContent ? 1 : 0) colorspace=\(name)"
    }

    public func present(rgba16f: UnsafeRawPointer, width: Int, height: Int, peakNits: Double) {
        guard let source = upload(rgba16f: rgba16f, width: width, height: height) else { return }
        draw(source, width: width, height: height, peakNits: peakNits)
    }

    public func present(ioSurface: IOSurface, width: Int, height: Int, peakNits: Double) {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        guard let source = device.makeTexture(descriptor: desc, iosurface: ioSurface, plane: 0) else { return }
        draw(source, width: width, height: height, peakNits: peakNits)
    }

    private func upload(rgba16f: UnsafeRawPointer, width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        guard let source = device.makeTexture(descriptor: desc) else { return nil }
        source.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: rgba16f,
            bytesPerRow: width * 8
        )
        return source
    }

    private func draw(_ source: MTLTexture, width: Int, height: Int, peakNits: Double) {
        guard width > 1, height > 1 else { return }
        scale = Float(max(peakNits, 203) / 203)
        let crop = CGRect(x: 0, y: 0, width: 1, height: 1).intersection(cropRect)
        let visible = crop.isNull || crop.width < 0.05 || crop.height < 0.05 ? CGRect(x: 0, y: 0, width: 1, height: 1) : crop
        layer.drawableSize = CGSize(
            width: max(2, (Double(width) * visible.width).rounded()),
            height: max(2, (Double(height) * visible.height).rounded())
        )
        var uvRect = SIMD4<Float>(
            Float(visible.minX),
            Float(1 - visible.maxY),
            Float(visible.width),
            Float(visible.height)
        )
        guard let drawable = layer.nextDrawable() else { return }
        guard let pipeline = pipeline ?? makePipeline(),
              let buffer = queue.makeCommandBuffer(),
              let pass = makePass(drawable.texture),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        self.pipeline = pipeline
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&uvRect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
        encoder.setFragmentTexture(source, index: 0)
        var gain = scale
        encoder.setFragmentBytes(&gain, length: MemoryLayout<Float>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
        presented = true
        presentedFrames += 1
    }

    private func makePass(_ texture: MTLTexture) -> MTLRenderPassDescriptor? {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return pass
    }

    private func makePipeline() -> MTLRenderPipelineState? {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct V { float4 p [[position]]; float2 uv; };
        vertex V buehne_v(uint id [[vertex_id]], constant float4 &rect [[buffer(0)]]) {
            float2 q[4] = {float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1)};
            float2 u[4] = {float2(0,0), float2(1,0), float2(0,1), float2(1,1)};
            V o; o.p = float4(q[id], 0, 1); o.uv = rect.xy + u[id] * rect.zw; return o;
        }
        fragment float4 buehne_f(V in [[stage_in]], texture2d<float> tex [[texture(0)]], constant float &gain [[buffer(0)]]) {
            constexpr sampler s(address::clamp_to_edge, filter::linear);
            float4 c = tex.sample(s, in.uv);
            float3 rgb = select(c.rgb, float3(0), isnan(c.rgb));
            rgb = clamp(rgb, float3(0), float3(16.0));
            return float4(rgb * gain, 1);
        }
        """
        guard let library = try? device.makeLibrary(source: source, options: nil),
              let vertex = library.makeFunction(name: "buehne_v"),
              let fragment = library.makeFunction(name: "buehne_f") else { return nil }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertex
        desc.fragmentFunction = fragment
        desc.colorAttachments[0].pixelFormat = .rgba16Float
        return try? device.makeRenderPipelineState(descriptor: desc)
    }
}
