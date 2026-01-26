# Ralph Event Versioning Module - Event Evolution and Migration
#
# Design Patterns Applied:
# - Event Versioning: Events can evolve without breaking existing systems
# - Schema Migration: Transform events between versions
# - Backward Compatibility: Old events can be read by new code
# - Forward Compatibility: New events can be processed by old code
#
# Features:
# - Semantic versioning for event types (e.g., TaskAssigned:v2)
# - Upcasters for migrating events to latest version
# - Automatic migration on read
# - Migration registry for tracking event evolution
#
# References:
# - https://martinfowler.com/eaaDev/EventSourcing.html
# - https://www.eventstore.com/docs/event-sourcing/evolving-events/

# ============================================================================
# VERSION MANAGEMENT
# ============================================================================

class EventVersion {
    [int]$Major
    [int]$Minor
    [int]$Patch

    EventVersion([int]$major, [int]$minor, [int]$patch) {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
    }

    EventVersion([string]$versionString) {
        if ($versionString -match '^v?(\d+)\.(\d+)\.(\d+)$') {
            $this.Major = [int]$matches[1]
            $this.Minor = [int]$matches[2]
            $this.Patch = [int]$matches[3]
        } elseif ($versionString -match '^v?(\d+)\.(\d+)$') {
            $this.Major = [int]$matches[1]
            $this.Minor = [int]$matches[2]
            $this.Patch = 0
        } elseif ($versionString -match '^v?(\d+)$') {
            $this.Major = [int]$matches[1]
            $this.Minor = 0
            $this.Patch = 0
        } else {
            throw "Invalid version string: $versionString"
        }
    }

    [string] ToString() {
        return "v$($this.Major).$($this.Minor).$($this.Patch)"
    }

    [int] CompareTo([EventVersion]$other) {
        if ($this.Major -ne $other.Major) {
            return $this.Major - $other.Major
        }
        if ($this.Minor -ne $other.Minor) {
            return $this.Minor - $other.Minor
        }
        return $this.Patch - $other.Patch
    }

    static [bool] operator <([EventVersion]$a, [EventVersion]$b) {
        return $a.CompareTo($b) -lt 0
    }

    static [bool] operator >([EventVersion]$a, [EventVersion]$b) {
        return $a.CompareTo($b) -gt 0
    }

    [EventVersion] NextMajor() {
        return [EventVersion]::new($this.Major + 1, 0, 0)
    }

    [EventVersion] NextMinor() {
        return [EventVersion]::new($this.Major, $this.Minor + 1, 0)
    }

    [EventVersion] NextPatch() {
        return [EventVersion]::new($this.Major, $this.Minor, $this.Patch + 1)
    }
}

# ============================================================================
# EVENT TYPE WITH VERSION
# ============================================================================

class VersionedEventType {
    [string]$BaseType
    [EventVersion]$Version

    VersionedEventType([string]$baseType, [EventVersion]$version) {
        $this.BaseType = $baseType
        $this.Version = $version
    }

    VersionedEventType([string]$baseType, [string]$versionString) {
        $this.BaseType = $baseType
        $this.Version = [EventVersion]::new($versionString)
    }

    [string] ToString() {
        return "$($this.BaseType):$($this.Version)"
    }

    [string] ToSerializedName() {
        return "$($this.BaseType):v$($this.Version.Major).$($this.Version.Minor).$($this.Version.Patch)"
    }

    static [VersionedEventType] Parse([string]$serialized) {
        if ($serialized -match '^(.+):v(\d+)\.(\d+)\.(\d+)$') {
            $baseType = $matches[1]
            $version = [EventVersion]::new(
                [int]$matches[2],
                [int]$matches[3],
                [int]$matches[4]
            )
            return [VersionedEventType]::new($baseType, $version)
        }
        # No version - assume v1.0.0
        return [VersionedEventType]::new($serialized, "1.0.0")
    }
}

# ============================================================================
# UPCASTER - Event transformation between versions
# ============================================================================

class EventUpcaster {
    [VersionedEventType]$SourceType
    [VersionedEventType]$TargetType
    [scriptblock]$Transform

    EventUpcaster(
        [string]$sourceBaseType,
        [string]$sourceVersion,
        [string]$targetVersion,
        [scriptblock]$transform
    ) {
        $this.SourceType = [VersionedEventType]::new($sourceBaseType, $sourceVersion)
        $this.TargetType = [VersionedEventType]::new($sourceBaseType, $targetVersion)
        $this.Transform = $transform
    }

    [hashtable] Apply([hashtable]$eventData) {
        if ($this.Transform) {
            return & $this.Transform $eventData
        }
        return $eventData
    }
}

# ============================================================================
# EVENT REGISTRY - Track all event types and their versions
# ============================================================================

class EventTypeRegistry {
    [Dictionary[string, EventVersion]]$EventVersions
    [Dictionary[string, VersionedEventType[]]]$UpcastersByType
    [EventVersion]$DefaultVersion

    EventTypeRegistry() {
        $this.EventVersions = [Dictionary[string, EventVersion]]::new()
        $this.UpcastersByType = [Dictionary[string, VersionedEventType[]]]::new()
        $this.DefaultVersion = [EventVersion]::new(1, 0, 0)
    }

    # Register an event type with its current version
    [void] RegisterEventType([string]$baseType, [EventVersion]$currentVersion) {
        $this.EventVersions[$baseType] = $currentVersion

        # Initialize upcaster list
        if (-not $this.UpcastersByType.ContainsKey($baseType)) {
            $this.UpcastersByType[$baseType] = [VersionedEventType[]]::new()
        }
    }

    [void] RegisterEventType([string]$baseType, [string]$versionString) {
        $this.RegisterEventType($baseType, [EventVersion]::new($versionString))
    }

    [void] RegisterEventType([string]$baseType) {
        $this.RegisterEventType($baseType, $this.DefaultVersion)
    }

    # Get current version for an event type
    [EventVersion] GetCurrentVersion([string]$baseType) {
        if ($this.EventVersions.ContainsKey($baseType)) {
            return $this.EventVersions[$baseType]
        }
        return $this.DefaultVersion
    }

    # Check if an event type is registered
    [bool] IsRegistered([string]$baseType) {
        return $this.EventVersions.ContainsKey($baseType)
    }

    # Create a serialized event type name with current version
    [string] CreateEventTypeName([string]$baseType) {
        $version = $this.GetCurrentVersion($baseType)
        $vet = [VersionedEventType]::new($baseType, $version)
        return $vet.ToSerializedName()
    }
}

# ============================================================================
# MIGRATION ENGINE - Apply upcasters to events
# ============================================================================

class EventMigrationEngine {
    [EventTypeRegistry]$Registry
    [Dictionary[string, EventUpcaster[]]]$Upcasters
    [Dictionary[string, int]]$MigrationCounts

    EventMigrationEngine([EventTypeRegistry]$registry) {
        $this.Registry = $registry
        $this.Upcasters = [Dictionary[string, EventUpcaster[]]]::new()
        $this.MigrationCounts = [Dictionary[string, int]]::new()
    }

    # Register an upcaster for migrating events
    [void] RegisterUpcaster([EventUpcaster]$upcaster) {
        $key = "$($upcaster.SourceType)"

        if (-not $this.Upcasters.ContainsKey($key)) {
            $this.Upcasters[$key] = [EventUpcaster[]]::new()
        }

        $existing = $this.Upcasters[$key]
        $newList = [List[EventUpcaster]]::new($existing)
        $newList.Add($upcaster)
        $this.Upcasters[$key] = $newList.ToArray()
    }

    [void] RegisterUpcaster(
        [string]$sourceType,
        [string]$fromVersion,
        [string]$toVersion,
        [scriptblock]$transform
    ) {
        $upcaster = [EventUpcaster]::new($sourceType, $fromVersion, $toVersion, $transform)
        $this.RegisterUpcaster($upcaster)
    }

    # Migrate a single event to the target version
    [hashtable] MigrateEvent([hashtable]$eventData, [EventVersion]$targetVersion) {
        # Parse current event type
        $eventType = $eventData.type
        $parsedType = [VersionedEventType]::Parse($eventType)
        $baseType = $parsedType.BaseType
        $currentVersion = $parsedType.Version

        # If already at target version, return as-is
        if ($currentVersion.CompareTo($targetVersion) -ge 0) {
            return $eventData
        }

        # Find and apply upcasters
        $result = $eventData
        $workingVersion = $currentVersion

        while ($workingVersion.CompareTo($targetVersion) -lt 0) {
            # Find upcaster for current version
            $upcasterKey = "$baseType:$workingVersion"

            if ($this.Upcasters.ContainsKey($upcasterKey)) {
                foreach ($upcaster in $this.Upcasters[$upcasterKey]) {
                    $result = $upcaster.Apply($result)
                    $workingVersion = $upcaster.TargetType.Version

                    # Update type in result
                    $newType = [VersionedEventType]::new($baseType, $workingVersion)
                    $result.type = $newType.ToSerializedName()

                    # Track migration
                    $migrationKey = "$baseType:$($currentVersion)->$workingVersion"
                    if (-not $this.MigrationCounts.ContainsKey($migrationKey)) {
                        $this.MigrationCounts[$migrationKey] = 0
                    }
                    $this.MigrationCounts[$migrationKey]++
                }
            } else {
                # No upcaster found - can't migrate further
                break
            }
        }

        return $result
    }

    # Migrate event to latest version
    [hashtable] MigrateToLatest([hashtable]$eventData) {
        $parsedType = [VersionedEventType]::Parse($eventData.type)
        $latestVersion = $this.Registry.GetCurrentVersion($parsedType.BaseType)

        return $this.MigrateEvent($eventData, $latestVersion)
    }

    # Migrate an array of events
    [hashtable[]] MigrateEvents([hashtable[]]$events, [EventVersion]$targetVersion) {
        $result = [List[hashtable]]::new()

        foreach ($evt in $events) {
            $migrated = $this.MigrateEvent($evt, $targetVersion)
            $result.Add($migrated)
        }

        return $result.ToArray()
    }

    [hashtable[]] MigrateEventsToLatest([hashtable[]]$events) {
        $result = [List[hashtable]]::new()

        foreach ($evt in $events) {
            $migrated = $this.MigrateToLatest($evt)
            $result.Add($migrated)
        }

        return $result.ToArray()
    }

    # Get migration statistics
    [hashtable] GetMigrationStats() {
        return @{
            TotalMigrations = ($this.MigrationCounts.Values | Measure-Object -Sum).Sum
            ByPath = $this.MigrationCounts
        }
    }
}

# ============================================================================
# COMMON EVENT DEFINITIONS WITH VERSIONING
# ============================================================================

class RalphEventTypes {
    static [string]$AgentStarted = "AgentStarted"
    static [string]$AgentExited = "AgentExited"
    static [string]$AgentCrashed = "AgentCrashed"
    static [string]$MessageSent = "MessageSent"
    static [string]$MessageDelivered = "MessageDelivered"
    static [string]$MessageAcked = "MessageAcked"
    static [string]$TaskAssigned = "TaskAssigned"
    static [string]$TaskCompleted = "TaskCompleted"
    static [string]$TaskAbandoned = "TaskAbandoned"
    static [string]$WatchdogStarted = "WatchdogStarted"
    static [string]$WatchdogStopped = "WatchdogStopped"
    static [string]$SessionInitialized = "SessionInitialized"
    static [string]$SnapshotCreated = "SnapshotCreated"
}

# ============================================================================
# BUILT-IN UPCASTERS - Common migrations for Ralph events
# ============================================================================

function Register-BuiltinUpcasters([EventMigrationEngine]$engine) {
    <#
    .SYNOPSIS
    Register built-in upcasters for Ralph event types.

    .DESCRIPTION
    Creates standard migrations for common Ralph events.
    These are examples that demonstrate upcaster patterns.

    Example: AgentStarted v1 -> v2
    v1: { agent: "pm", pid: 12345 }
    v2: { agent: "pm", pid: 12345, startTime: "2024-01-01T00:00:00Z" }
    #>

    # AgentStarted v1 -> v2: Add startTime field
    $engine.RegisterUpcaster(
        "AgentStarted",
        "v1.0.0",
        "v2.0.0",
        {
            param($evt)
            $evt.data.startTime = if ($evt.data.timestamp) {
                $evt.data.timestamp
            } else {
                [DateTime]::UtcNow.ToString("o")
            }
            $evt.data.version = "2.0.0"
            return $evt
        }.GetNewClosure()
    )

    # MessageSent v1 -> v2: Add priority and correlationId
    $engine.RegisterUpcaster(
        "MessageSent",
        "v1.0.0",
        "v2.0.0",
        {
            param($evt)
            $evt.data.priority = if ($evt.data.priority) { $evt.data.priority } else { 0 }
            $evt.data.correlationId = if ($evt.data.correlationId) {
                $evt.data.correlationId
            } else {
                [Guid]::NewGuid().ToString()
            }
            return $evt
        }.GetNewClosure()
    )

    # TaskAssigned v1 -> v2: Add retryCount and deadline
    $engine.RegisterUpcaster(
        "TaskAssigned",
        "v1.0.0",
        "v2.0.0",
        {
            param($evt)
            $evt.data.retryCount = if ($evt.data.retryCount) { $evt.data.retryCount } else { 0 }
            $evt.data.maxRetries = if ($evt.data.maxRetries) { $evt.data.maxRetries } else { 3 }
            if (-not $evt.data.deadline) {
                $evt.data.deadline = ([DateTime]::UtcNow.AddHours(24)).ToString("o")
            }
            return $evt
        }.GetNewClosure()
    )
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function New-EventTypeRegistry {
    <#
    .SYNOPSIS
    Create a new event type registry.

    .RETURNS
    EventTypeRegistry instance.
    #>
    return [EventTypeRegistry]::new()
}

function New-MigrationEngine {
    <#
    .SYNOPSIS
    Create a new event migration engine.

    .PARAMETER Registry
    Optional EventTypeRegistry to use. Creates new if not provided.

    .RETURNS
    EventMigrationEngine instance.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [EventTypeRegistry]$Registry
    )

    if ($null -eq $Registry) {
        $Registry = [EventTypeRegistry]::new()
    }

    $engine = [EventMigrationEngine]::new($Registry)

    # Register built-in upcasters
    Register-BuiltinUpcasters($engine)

    return $engine
}

function Register-EventType {
    <#
    .SYNOPSIS
    Register an event type in the registry.

    .PARAMETER Registry
    The EventTypeRegistry to register with.

    .PARAMETER BaseType
    The base event type name (e.g., "TaskAssigned").

    .PARAMETER Version
    The current version (defaults to v1.0.0).

    .EXAMPLE
    $registry = New-EventTypeRegistry
    Register-EventType -Registry $registry -BaseType "TaskAssigned" -Version "2.1.0"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [EventTypeRegistry]$Registry,

        [Parameter(Mandatory=$true)]
        [string]$BaseType,

        [Parameter(Mandatory=$false)]
        [string]$Version = "1.0.0"
    )

    $Registry.RegisterEventType($BaseType, $Version)
}

function Register-EventUpcaster {
    <#
    .SYNOPSIS
    Register an event upcaster for migration.

    .PARAMETER Engine
    The EventMigrationEngine to register with.

    .PARAMETER BaseType
    The base event type name.

    .PARAMETER FromVersion
    Source version (e.g., "v1.0.0").

    .PARAMETER ToVersion
    Target version (e.g., "v2.0.0").

    .PARAMETER Transform
    Scriptblock that transforms event data.

    .EXAMPLE
    Register-EventUpcaster -Engine $engine -BaseType "TaskAssigned" `
        -FromVersion "v1.0.0" -ToVersion "v2.0.0" `
        -Transform { param($evt) $evt.data.newField = "value"; return $evt }
    #>
    param(
        [Parameter(Mandatory=$true)]
        [EventMigrationEngine]$Engine,

        [Parameter(Mandatory=$true)]
        [string]$BaseType,

        [Parameter(Mandatory=$true)]
        [string]$FromVersion,

        [Parameter(Mandatory=$true)]
        [string]$ToVersion,

        [Parameter(Mandatory=$true)]
        [scriptblock]$Transform
    )

    $upcaster = [EventUpcaster]::new($BaseType, $FromVersion, $ToVersion, $Transform)
    $Engine.RegisterUpcaster($upcaster)
}

function New-VersionedEvent {
    <#
    .SYNOPSIS
    Create a new event with versioning.

    .PARAMETER Registry
    The EventTypeRegistry to get current version from.

    .PARAMETER BaseType
    The base event type name.

    .PARAMETER Data
    Event data as hashtable.

    .PARAMETER Metadata
    Optional metadata.

    .RETURNS
    Hashtable representing the event.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [EventTypeRegistry]$Registry,

        [Parameter(Mandatory=$true)]
        [string]$BaseType,

        [Parameter(Mandatory=$true)]
        [hashtable]$Data,

        [Parameter(Mandatory=$false)]
        [hashtable]$Metadata = @{}
    )

    $version = $Registry.GetCurrentVersion($BaseType)
    $vet = [VersionedEventType]::new($BaseType, $version)

    return @{
        type = $vet.ToSerializedName()
        data = $Data
        metadata = $Metadata
        timestamp = [DateTime]::UtcNow.ToString("o")
    }
}

# ============================================================================
# EXPORTS
# ============================================================================

try {
    Export-ModuleMember -Function @(
        # Constructors
        'New-EventTypeRegistry',
        'New-MigrationEngine',

        # Registry functions
        'Register-EventType',
        'Register-EventUpcaster',

        # Event creation
        'New-VersionedEvent',

        # Classes
        'EventVersion',
        'VersionedEventType',
        'EventTypeRegistry',
        'EventMigrationEngine',

        # Constants
        'RalphEventTypes'
    )
} catch {
    # Not running as a module
}
