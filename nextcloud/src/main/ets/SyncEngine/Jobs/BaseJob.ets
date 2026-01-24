import { Logger } from '../../Index';

export enum JobState {
    PENDING = 'pending',
    IN_PROGRESS = 'in_progress',
    COMPLETED = 'completed',
    FAILED = 'failed'
}

export interface JobData {}

export class BaseJob {
    public readonly jobName: string;
    protected readonly TAG: string;
    protected state: JobState = JobState.PENDING;
    private stateListeners: Array<(state: string) => void> = [];

    constructor(name: string) {
        this.jobName = name;
        this.TAG = `Jobs/${this.jobName}`;
    }

    public get jobState(): string {
        return this.state;
    }

    public addStateListener(listener: (state: string) => void): void {
        this.stateListeners.push(listener);
    }

    public removeStateListener(listener: (state: string) => void): void {
        this.stateListeners = this.stateListeners.filter(l => l !== listener);
    }

    public start(): Promise<void> {
        this.setState(JobState.IN_PROGRESS);
        let promise = new Promise<void>(async (resolve, reject) => {
            try {
                Logger.Info(this.TAG, `Job ${this.jobName} started.`);
                await this.onWork();
                setTimeout(() => {
                    this.setState(JobState.COMPLETED);
                    Logger.Info(this.TAG, `Job ${this.jobName} completed.`);
                    resolve();
                }, 1000);
            } catch (error) {
                this.setState(JobState.FAILED);
                Logger.Error(this.TAG, `Job ${this.jobName} failed with error: ${error}`);
                reject(error);
            }
        });

        return promise;
    }

    protected async onWork(): Promise<void> {
        throw new Error(`onWork method not implemented for job ${this.jobName}`);
    }

    private setState(newState: JobState) {
        this.state = newState;
        this.stateListeners.forEach(listener => listener(this.state));
    }
}
