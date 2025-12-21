export function FormatBytes(bytes: string) {
    let bytesNum = parseInt(bytes);
    let units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let i = 0;
    while (bytesNum >= 1024) {
        bytesNum /= 1024;
        i++;
    }

    return bytesNum.toFixed(2) + ' ' + units[i];
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
