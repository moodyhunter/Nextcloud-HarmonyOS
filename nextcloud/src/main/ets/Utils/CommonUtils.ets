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
