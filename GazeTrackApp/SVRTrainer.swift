import Foundation
import simd

/// 支持向量回归模型（使用 ε-insensitive SVR + RBF核）
struct SVRModel {
    let supportVectors: [[Float]]
    let coefficients: [Float]
    let bias: Float
    let mean: [Float]
    let std: [Float]
    let gamma: Float

    func normalize(_ x: [Float]) -> [Float] {
        zip(x.indices, x).map { i, xi in
            (xi - mean[i]) / (std[i] != 0 ? std[i] : 1)
        }
    }

    func predict(_ x: [Float]) -> Float {
        let xNorm = normalize(x)
        var sum: Float = 0
        for (i, sv) in supportVectors.enumerated() {
            let pairs = zip(sv, xNorm)
            let squaredDistance = pairs.map { (a, b) in (a - b) * (a - b) }.reduce(0, +)
            sum += coefficients[i] * exp(-gamma * squaredDistance)
        }
        return sum + bias
    }

    func predictFromGaze(_ gaze: SIMD3<Float>) -> Float {
        return predict([gaze.x, gaze.y, gaze.z])
    }
}

struct SVRTrainer {
    static func train(fromGaze gazes: [SIMD3<Float>], targets: [Float], gamma: Float = 1.0, C: Float = 10.0, epsilon: Float = 0.01) -> SVRModel {
        let inputs: [[Float]] = gazes.map { gaze in
            [gaze.x, gaze.y, gaze.z]
        }
        return train(inputs: inputs, targets: targets, gamma: gamma, C: C, epsilon: epsilon)
    }

    static func train(inputs: [[Float]], targets: [Float], gamma: Float = 1.0, C: Float = 10.0, epsilon: Float = 0.01) -> SVRModel {
        let n = inputs.count
        let dim = inputs[0].count

        // 1. 标准化
        var mean = [Float](repeating: 0, count: dim)
        var std = [Float](repeating: 0, count: dim)
        for i in 0..<dim {
            let values = inputs.map { $0[i] }
            let m = values.reduce(0, +) / Float(n)
            let s = sqrt(values.map { pow($0 - m, 2) }.reduce(0, +) / Float(n))
            mean[i] = m
            std[i] = s
        }
        let normInputs = inputs.map { x in
            zip(x.indices, x).map { i, xi in
                (xi - mean[i]) / (std[i] != 0 ? std[i] : 1)
            }
        }

        // 2. 构建内核矩阵
        var K = [[Float]](repeating: [Float](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n {
                let zipped = zip(normInputs[i], normInputs[j])
                let diff = zipped.map { (a, b) in (a - b) * (a - b) }.reduce(0, +)
                K[i][j] = exp(-gamma * diff)
            }
        }

        // 3. 初始化 alpha、alphaStar、bias
        var alpha = [Float](repeating: 0, count: n)
        var alphaStar = [Float](repeating: 0, count: n)
        var bias: Float = 0
        let tol: Float = 1e-3

        // 4. SMO 主循环（简化版）
        for _ in 0..<5000 {
            var changed = false
            for i in 0..<n {
                let dotTerms = (0..<n).map { j in (alpha[j] - alphaStar[j]) * K[j][i] }
                let f_i = dotTerms.reduce(0, +) + bias
                let E_i = f_i - targets[i]

                if (alpha[i] < C && E_i < -epsilon - tol) ||
                   (alpha[i] > 0 && E_i > -epsilon + tol) ||
                   (alphaStar[i] < C && E_i > epsilon + tol) ||
                   (alphaStar[i] > 0 && E_i < epsilon - tol) {

                    let j = (i + 1) % n
                    let terms_j = (0..<n).map { k in (alpha[k] - alphaStar[k]) * K[k][j] }
                    let f_j = terms_j.reduce(0, +) + bias
                    let E_j = f_j - targets[j]

                    let eta = 2 * K[i][j] - K[i][i] - K[j][j]
                    if eta >= 0 { continue }

                    let alpha_j_old = alpha[j]
                    var alpha_j_new = alpha_j_old - (E_i - E_j) / eta

                    alpha_j_new = min(C, max(0, alpha_j_new))
                    if abs(alpha_j_new - alpha_j_old) < 1e-5 { continue }

                    let alpha_i_old = alpha[i]
                    let alpha_i_new = alpha_i_old + (alpha_j_old - alpha_j_new)

                    alpha[i] = alpha_i_new
                    alpha[j] = alpha_j_new

                    let b1 = bias - E_i - (alpha_i_new - alpha_i_old) * K[i][i] - (alpha_j_new - alpha_j_old) * K[i][j]
                    let b2 = bias - E_j - (alpha_i_new - alpha_i_old) * K[i][j] - (alpha_j_new - alpha_j_old) * K[j][j]

                    if 0 < alpha_i_new && alpha_i_new < C {
                        bias = b1
                    } else if 0 < alpha_j_new && alpha_j_new < C {
                        bias = b2
                    } else {
                        bias = (b1 + b2) / 2
                    }

                    changed = true
                }
            }
            if !changed { break }
        }

        // 5. 提取支持向量
        var sv: [[Float]] = []
        var coefs: [Float] = []
        for i in 0..<n {
            let coeff = alpha[i] - alphaStar[i]
            if abs(coeff) > 1e-5 {
                sv.append(normInputs[i])
                coefs.append(coeff)
            }
        }

        return SVRModel(
            supportVectors: sv,
            coefficients: coefs,
            bias: bias,
            mean: mean,
            std: std,
            gamma: gamma
        )
    }
}
