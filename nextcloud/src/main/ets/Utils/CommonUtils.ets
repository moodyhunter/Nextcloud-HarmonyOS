import util from "@ohos.util";

let Base64Util = new util.Base64Helper();
let Utf8Encoder = util.TextEncoder.create('utf-8');

export async function AsyncSleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
        setTimeout(() => {
            resolve();
        }, ms);
    });
}

export function Base64Encode(msg: string): string {
    return Base64Util.encodeToStringSync(Utf8Encoder.encodeInto(msg));
}

export function FormatTime(date: Date, format: string) {
    // make sure the path format ends with a slash
    if (!format.endsWith('/')) {
        format += '/';
    }

    let result = format;
    result = result.replace('yyyy', date.getFullYear().toString());
    result = result.replace('MM', (date.getMonth() + 1).toString().padStart(2, '0'));
    result = result.replace('dd', date.getDate().toString().padStart(2, '0'));
    result = result.replace('HH', date.getHours().toString().padStart(2, '0'));
    result = result.replace('mm', date.getMinutes().toString().padStart(2, '0'));
    result = result.replace('ss', date.getSeconds().toString().padStart(2, '0'));
    return result;
}
