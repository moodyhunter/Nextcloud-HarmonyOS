import { Logger } from '../../Index';

export enum JobState {
    PENDING = 'pending',
    IN_PROGRESS = 'in_progress',
    COMPLETED = 'completed',
    FAILED = 'failed'
}

export interface JobData {}

type JobStateListener = (job: BaseJob, state: JobState) => void;

export class BaseJob {
    public readonly jobName: string;
    protected readonly TAG: string;
    protected state: JobState = JobState.PENDING;
    private stateListeners: Array<JobStateListener> = [];
    private stateHistory: JobState[] = [];

    constructor(name: string) {
        this.jobName = name;
        this.TAG = `Jobs/${this.jobName}`;
        this.stateHistory.push(JobState.PENDING);
    }

    public get jobState(): string {
        return this.state;
    }

    public addStateListener(listener: JobStateListener): void {
        this.stateListeners.push(listener as JobStateListener);
        for (const state of this.stateHistory) {
            listener(this, state);
        }
    }

    public removeStateListener(listener?: JobStateListener): void {
        if (listener === undefined) {
            this.stateListeners = [];
        } else {
            this.stateListeners = this.stateListeners.filter(l => l !== listener);
        }
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
        this.stateHistory.push(newState);
        this.stateListeners.forEach(listener => listener(this, newState));
    }
}
