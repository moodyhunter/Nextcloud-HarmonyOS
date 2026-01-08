import { Logger } from '../Utils/Logger';
import { Configuration, CoreClientFlowLoginV2Api, CoreLoginFlowV2Credentials } from '../nextcloud-api-sdk';
import { NCommon } from '../Common';
import { AxiosError } from '@ohos/axios';

const TAG = "Nextcloud-Login";

interface InitLoginResult {
    success: boolean;
    loginUrl?: string;
    errorMsg?: string;
};

interface PollLoginResult {
    cancelled: boolean;
    loginName: string;
}

class LoginProcess {
    private loginApi: CoreClientFlowLoginV2Api | null = null;
    private token: string = "";
    private cancelled: boolean = false;

    hasAppPassword(): boolean {
        return NCommon.Preference.password !== "";
    }

    async initLogin(): Promise<InitLoginResult> {
        let apiConfig = new Configuration({
            basePath: "https://" + NCommon.Preference.hostname,
            baseOptions: {
                headers: { "User-Agent": NCommon.UserAgent() },
            }
        });

        this.loginApi = new CoreClientFlowLoginV2Api(apiConfig);
        try {
            let flow = (await this.loginApi.coreClientFlowLoginV2Init()).data;
            this.token = flow.poll.token;
            return { success: true, loginUrl: flow.login };
        } catch (e) {
            let axiosError: AxiosError = e as AxiosError;
            Logger.Error(TAG, "LoginV2Init failed: " + e);
            if (Number(axiosError.code) === 2300006) {
                return { success: false, errorMsg: (JSON.parse(axiosError.message) as Error).message };
            } else {
                return { success: false, errorMsg: axiosError.message };
            }
        }
    }

    public cancelPolling(): void {
        this.cancelled = true;
    }

    async loginPollRepeatedly(): Promise<PollLoginResult> {
        Logger.Info(TAG, "Polling for login result...");
        this.cancelled = false;
        let result = await this.loginPollOnce();
        while (!result) {
            if (this.cancelled) {
                return {
                    loginName: '',
                    cancelled: true
                };
            }
            await new Promise<never>(resolve => setTimeout(resolve, 1500));
            result = await this.loginPollOnce();
        }

        NCommon.Preference.password = result.appPassword;
        NCommon.Preference.username = result.loginName;
        return {
            cancelled: false,
            loginName: result.loginName,
        };
    }

    private async loginPollOnce(): Promise<CoreLoginFlowV2Credentials | null> {
        try {
            Logger.Debug(TAG, "  -> Polling...");
            return (await this.loginApi!.coreClientFlowLoginV2Poll(this.token)).data;
        } catch (e) {
            return null;
        }
    }
}

export { LoginProcess };
