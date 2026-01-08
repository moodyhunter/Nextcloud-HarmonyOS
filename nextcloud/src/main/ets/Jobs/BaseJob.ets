import { Logger } from "../Index";

export class BaseJob {
    public readonly jobName: string;
    protected readonly TAG: string;

    constructor(name: string) {
        this.jobName = name;
        this.TAG = `Jobs/${this.jobName}`;
    }

    async doWork(): Promise<void> {
        Logger.Info(this.TAG, `doWork unimplemented`);
    }
}