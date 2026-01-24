// SPDX-License-Identifier: GPL-3.0-or-later
import hilog from '@ohos.hilog'

const DOMAIN = 0xABAB;

export class Logger {
    static Debug(component: string, ...message: string[]) {
        hilog.debug(DOMAIN, component, message.join(', '))
    }

    static Info(component: string, ...message: string[]) {
        hilog.info(DOMAIN, component, message.join(', '))
    }

    static Warn(component: string, ...message: string[]) {
        hilog.warn(DOMAIN, component, message.join(', '))
    }

    static Error(component: string, ...message: string[]) {
        hilog.error(DOMAIN, component, message.join(', '))
    }
}
