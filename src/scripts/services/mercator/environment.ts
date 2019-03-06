import * as fs from "fs";

import {
    IApiClient,
    IApplicationModel,
    IContext,
    IDataModel,
    IEnvironment,
    ILogger,
} from "./typings";

import * as msRestAzure from "ms-rest-azure";

import { ApiClient } from "./apiClient";
import { ApplicationModel } from "./applicationModel";
import { DataModel } from "./dataModel";
import { Logger } from "./logger";
import { Settings } from "./settings";

class Environment implements IEnvironment {
    public static async loadPackage(): Promise<object> {
        return new Promise((resolve, reject) => {
            fs.readFile(__dirname + "/../package.json", (error, data) => {
                if (error) { return reject(error); }
                return resolve(JSON.parse(data.toString()));
            });
        });
    }

    public static isEnabled(): boolean {
        // check if enabled
        return Settings.isEnabled;
    }

    public static async createInstance(context: IContext): Promise<IEnvironment> {
        return Logger.enterAsync<IEnvironment>("Environment.createInstance", async () => {
            // get package
            const pkg: any = await Environment.loadPackage();
            // init logger
            const logger = await Logger.createInstance(context, { category: pkg.name });
            // create environment
            const model = new Environment(logger, pkg.name);
            // initialize
            await model.initialize();
            // all done
            return model;
        });
    }

    public api: IApiClient;
    public name: string;
    public logger: ILogger;
    public data: IDataModel;
    public application: IApplicationModel;
    public settings: Settings;
    public credentials: any;
    constructor(logger: ILogger, name: string) {
        Logger.enter("Environment.constructor", () => {
            this.name = name;
            this.logger = logger;
        });
    }

    private async initialize(): Promise<void> {
        return Logger.enterAsync<void>("Environment.initialize", async () => {
            if (Environment.isEnabled()) {
                // get credentials
                this.credentials = await msRestAzure.loginWithAppServiceMSI();
                // get settings
                this.settings = await Settings.get();
                // create api
                this.api = await ApiClient.createInstance(this.credentials,
                    this.settings.subscriptionId,
                    this.settings.storageAccountId,
                    this.settings.storageAccountKey,
                );
                // create data model
                this.data = await DataModel.createInstance(this.api);
                // creates options for this instance
                const options = {
                    resourceGroup: this.settings.resourceGroup,
                    storageAccountId: this.settings.storageAccountId,
                    subscriptionId: this.settings.subscriptionId,
                    topicId: this.settings.statusTopicId,
                };
                // create application model
                this.application = await ApplicationModel.createInstance(this, options);
            }
        });
    }
}

export { Environment };
