#pragma once
#define LOG_DOMAIN 0

#include <hilog/log.h>

#define LogFmt(fmt, ...) "[%{public}s:%{public}d] " fmt, __func__, __LINE__, ##__VA_ARGS__

#define LogE(fmt, ...) OH_LOG_Print(LogType::LOG_APP, LogLevel::LOG_ERROR, LOG_DOMAIN, LOG_TAG, LogFmt(fmt, ##__VA_ARGS__))
#define LogW(fmt, ...) OH_LOG_Print(LogType::LOG_APP, LogLevel::LOG_WARN, LOG_DOMAIN, LOG_TAG, LogFmt(fmt, ##__VA_ARGS__))
#define LogI(fmt, ...) OH_LOG_Print(LogType::LOG_APP, LogLevel::LOG_INFO, LOG_DOMAIN, LOG_TAG, LogFmt(fmt, ##__VA_ARGS__))
#define LogD(fmt, ...) OH_LOG_Print(LogType::LOG_APP, LogLevel::LOG_DEBUG, LOG_DOMAIN, LOG_TAG, LogFmt(fmt, ##__VA_ARGS__))

// clang-format off
#define NAPI_ERR_RET(expr, msg, ...) if ((expr) != napi_ok) { LogI(msg, ##__VA_ARGS__); return; }
// clang-format on
