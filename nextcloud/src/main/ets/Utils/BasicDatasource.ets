@Observed
export class BasicDataSource<T> implements IDataSource {
    protected entries: T[] = [];
    private listeners: DataChangeListener[] = [];

    public totalCount(): number {
        return this.entries.length;
    }

    public getData(index: number): T {
        return this.entries[index];
    }

    public getDataRange(start: number, count: number): T[] {
        return this.entries.slice(start, start + count);
    }

    public prependItem(item: T): T {
        this.entries.unshift(item);
        this.notifyDataAdd(0);
        return this.entries[0];
    }

    public appendItem(item: T) {
        this.entries.push(item);
        this.notifyDataAdd(this.entries.length - 1);
    }

    public clear() {
        this.entries.length = 0;
        this.notifyDataReload();
    }

    registerDataChangeListener(listener: DataChangeListener): void {
        if (this.listeners.indexOf(listener) < 0) {
            this.listeners.push(listener);
        }
    }

    unregisterDataChangeListener(listener: DataChangeListener): void {
        const pos = this.listeners.indexOf(listener);
        if (pos >= 0) {
            this.listeners.splice(pos, 1);
        }
    }

    notifyDataReload(): void {
        this.listeners.forEach(listener => {
            listener.onDataReloaded();
        })
    }

    notifyDataAdd(index: number): void {
        this.listeners.forEach(listener => {
            listener.onDataAdd(index);
        })
    }

    notifyDataChange(index: number): void {
        this.listeners.forEach(listener => {
            listener.onDataChange(index);
        })
    }

    notifyDataDelete(index: number): void {
        this.listeners.forEach(listener => {
            listener.onDataDelete(index);
        })
    }

    notifyDataMove(from: number, to: number): void {
        this.listeners.forEach(listener => {
            listener.onDataMove(from, to);
        })
    }

    notifyDatasetChange(operations: DataOperation[]): void {
        this.listeners.forEach(listener => {
            listener.onDatasetChange(operations);
        })
    }
}
