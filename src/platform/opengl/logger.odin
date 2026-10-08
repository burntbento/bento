package platform_opengl

import "bento:engine"
import "core:fmt"
import sdl "vendor:sdl3"

@(private)
priorities_to_sdl :: proc(level: engine.LoggerLevels) -> sdl.LogPriority {
	#partial switch level {
	case .TRACE:
		return sdl.LogPriority.TRACE
	case .VERBOSE:
		return sdl.LogPriority.VERBOSE
	case .DEBUG:
		return sdl.LogPriority.DEBUG
	case .INFO:
		return sdl.LogPriority.INFO
	case .WARN:
		return sdl.LogPriority.WARN
	case .ERROR:
		return sdl.LogPriority.ERROR
	case .CRITICAL:
		return sdl.LogPriority.CRITICAL
	case:
		return sdl.LogPriority.INVALID
	}
}

init_logger :: proc(level: engine.LoggerLevels) {
	sdl.SetLogPriorities(priorities_to_sdl(level))
}

logger :: proc(level: engine.LoggerLevels, msg: string, args: ..any) {
	cmessage := fmt.ctprintf(msg, ..args)
	sdl.LogMessage(cast(i32)sdl.LogCategory.CUSTOM, priorities_to_sdl(level), cmessage)
}
