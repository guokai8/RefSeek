import Foundation

/// Ollama local LLM integration for smart query expansion
/// Requires Ollama running locally (ollama.com)
enum OllamaHelper {

    struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let stream: Bool
    }

    struct GenerateResponse: Decodable {
        let response: String?
    }

    /// Default Ollama endpoint
    static let defaultURL = "http://localhost:11434"

    /// Check if Ollama is running locally
    static func isAvailable() async -> Bool {
        guard let url = URL(string: "\(defaultURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Get available models from local Ollama
    static func availableModels() async -> [String] {
        guard let url = URL(string: "\(defaultURL)/api/tags") else { return [] }
        struct TagsResponse: Decodable {
            struct Model: Decodable {
                let name: String
            }
            let models: [Model]?
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            return decoded.models?.map(\.name) ?? []
        } catch {
            return []
        }
    }

    /// Use LLM to expand/improve a search query for academic papers
    static func expandQuery(_ query: String, model: String = "llama3.2") async -> String? {
        guard let url = URL(string: "\(defaultURL)/api/generate") else { return nil }

        let prompt = """
        You are an academic search assistant. Given the user's search query, generate an improved, \
        more specific search query for finding academic papers. Return ONLY the improved query, \
        nothing else. Keep it concise (under 20 words). Use proper academic terminology.

        User query: \(query)

        Improved query:
        """

        let body = GenerateRequest(model: model, prompt: prompt, stream: false)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            let result = decoded.response?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
            // Sanity check: don't return if too long or empty
            if let r = result, !r.isEmpty, r.count < 200 {
                return r
            }
            return nil
        } catch {
            return nil
        }
    }

    /// General-purpose generate call
    static func generate(prompt: String, model: String = "llama3.2", timeout: TimeInterval = 60) async -> String? {
        guard let url = URL(string: "\(defaultURL)/api/generate") else { return nil }

        let body = GenerateRequest(model: model, prompt: prompt, stream: false)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            return decoded.response?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    /// Summarize an abstract using local LLM
    static func summarize(_ text: String, model: String = "llama3.2") async -> String? {
        guard let url = URL(string: "\(defaultURL)/api/generate") else { return nil }

        let prompt = """
        Summarize this academic paper abstract in 2-3 sentences, focusing on the key findings:

        \(text.prefix(2000))

        Summary:
        """

        let body = GenerateRequest(model: model, prompt: prompt, stream: false)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            return decoded.response?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
