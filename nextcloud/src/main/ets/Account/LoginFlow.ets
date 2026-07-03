import { Logger } from '../Utils/Logger';
import { Configuration, CoreClientFlowLoginV2Api, CoreLoginFlowV2Credentials } from '../nextcloud-api-sdk';
import { AxiosError } from '@ohos/axios';
import { AsyncSleep } from '../Utils/CommonUtils';
import { Err, Ok, Result } from '../Utils/Result';
import { Account } from './Account';
import { NCommon } from '../Common';

const TAG = 'Account/Login';

interface PollLoginResultOk {
    kind: "ok";
    account: Account;
}

interface PollLoginResultCancelled {
    kind: "cancelled";
}

type PollLoginResult = PollLoginResultOk | PollLoginResultCancelled;

export class LoginFlow {
    private loginApi: CoreClientFlowLoginV2Api | null = null;
    private token: string = '';
    private cancelled: boolean = false;
    private hostname: string = '';

    async initLogin(hostname: string): Promise<Result<string, string>> {
        this.hostname = hostname;
        let apiConfig = new Configuration({
            basePath: "https://" + hostname,
            baseOptions: {
                headers: { "User-Agent": NCommon.UserAgent() },
            }
        });

        this.loginApi = new CoreClientFlowLoginV2Api(apiConfig);
        try {
            let flow = (await this.loginApi.coreClientFlowLoginV2Init()).data;
            this.token = flow.poll.token;
            return Ok(flow.login);
        } catch (e) {
            Logger.Error(TAG, "LoginV2Init failed: " + JSON.stringify(e));
            let axiosError: AxiosError = e as AxiosError;
            if (Number(axiosError.code) === 2300006) {
                return Err((JSON.parse(axiosError.message) as Error).message);
            } else {
                return Err("Network error");
            }
        }
    }

    public cancelPolling(): void {
        this.cancelled = true;
    }

    async loginPollRepeatedly(): Promise<PollLoginResult> {
        Logger.Info(TAG, "Polling for login result...");
        this.cancelled = false;

        let result: CoreLoginFlowV2Credentials | null;
        do {
            if (this.cancelled) {
                return { kind: "cancelled" };
            }
            await AsyncSleep(1500);
            result = await this.loginPollOnce();
        } while (result === null);

        return {
            kind: 'ok',
            account: Account.createNewAccount(this.hostname, result.loginName, result.appPassword)
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
