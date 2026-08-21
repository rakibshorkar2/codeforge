import Foundation

protocol AgentTool: AnyObject {
    var name: String { get }
    var description: String { get }
    var requiredPermission: PermissionLevel { get }
    var definition: AgentToolDefinition { get }

    func execute(parameters: [String: Any], workspace: String) throws -> String
}

extension AgentTool {
    var definition: AgentToolDefinition {
        AgentToolDefinition(name: name, description: description, parameters: [])
    }
}

final class AgentToolRegistry {
    private var tools: [String: AgentTool] = [:]

    var availableTools: [AgentTool] {
        Array(tools.values)
    }

    func register(_ tool: AgentTool) {
        tools[tool.name] = tool
    }

    func tool(named name: String) -> AgentTool? {
        tools[name]
    }

    func toolDefinitions() -> [AgentToolDefinition] {
        tools.values.map(\.definition)
    }

    static func defaultRegistry(workspace: String, permissionManager: AgentPermissionManagerProtocol, auditLog: AgentAuditLogProtocol) -> AgentToolRegistry {
        let registry = AgentToolRegistry()
        registry.register(ReadFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(WriteFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(EditFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(CreateFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(DeleteFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(RenameFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(MoveFileTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(CreateDirectoryTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(ListDirectoryTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(SearchFilesTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(SearchTextTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(GetFileMetadataTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        registry.register(GetProjectStructureTool(workspace: workspace, permissions: permissionManager, auditLog: auditLog))
        return registry
    }
}
