import * as KeyVault from "azure-keyvault";
import * as msRestAzure from "ms-rest-azure";
import { Logger } from "./logger";
import {
    ILogger,
} from "./typings";

class Settings {
    public static get isEnabled(): boolean {
        const uri = global.process.env.KEY_VAULT_URI;
        return uri !== undefined && uri !== null && uri !== "";
    }
    public static async get(credentials?: msRestAzure.MSITokenCredentials): Promise<Settings> {
        // set options
        const options: msRestAzure.MSIAppServiceOptions = {
            msiEndpoint: global.process.env.MSI_ENDPOINT,
            msiSecret: global.process.env.MSI_SECRET,
            resource: "https://vault.azure.net",
        };
        // get credentials
        credentials = credentials || await msRestAzure.loginWithAppServiceMSI(options);
        // get keyvault client
        const client = new KeyVault.KeyVaultClient(credentials);
        // get various secrets
        const webHookUri = global.process.env.WEB_HOOK_URI ||
            await Settings.secret(client, "WebHookUri", global.process.env.WEB_HOOK_URI);
        const storageAccountKey = global.process.env.STORAGE_ACCOUNT_KEY ||
            await Settings.secret(client, "StorageAccountKey", global.process.env.STORAGE_ACCOUNT_KEY);
        // return value or null
        return new Settings(
            global.process.env.AZURE_SUBSCRIPTION_ID,
            global.process.env.RESOURCE_GROUP_NAME,
            global.process.env.KEY_VAULT_URI,
            global.process.env.STORAGE_ACCOUNT_ID,
            storageAccountKey,
            global.process.env.STATUS_TOPIC_ID,
            webHookUri,
            global.process.env.APPINSIGHTS_INSTRUMENTATIONKEY,
        );
    }

    private static async secret(client: KeyVault.KeyVaultClient, name: string, def?: string): Promise<string> {
        return Logger.enterAsync<string>("Settings.secret", async () => {
            // get uri
            const uri = global.process.env.KEY_VAULT_URI;
            // check if valid
            if (uri !== undefined && uri !== null && uri !== "") {
                // get secret
                const secret = await client.getSecret(global.process.env.KEY_VAULT_URI, name, "");
                // return value or null
                return secret !== null ? secret.value : def;
            } else {
                // default to be returned
                return def;
            }
        });
    }
    public get resourceGroup(): string {
        return this.settingsResourceGroup;
    }
    public get statusTopicId(): string {
        return this.settingsStatusTopicId;
    }
    public get subscriptionId(): string {
        return this.settingsSubscriptionId;
    }
    public get storageAccountId(): string {
        return this.settingsStorageAccountId;
    }
    public get keyVaultUri(): string {
        return this.settingsKeyVaultUri;
    }
    public get storageAccountKey(): string {
        return this.settingsStorageAccountKey;
    }
    public get webHookUri(): string {
        return this.settingsWebHookUri;
    }
    public get applicationInsightsKey(): string {
        return this.settingsApplicationInsightsKey;
    }

    private settingsResourceGroup: string;
    private settingsStatusTopicId: string;
    private settingsSubscriptionId: string;
    private settingsStorageAccountId: string;
    private settingsKeyVaultUri: string;
    private settingsStorageAccountKey: string;
    private settingsWebHookUri: string;
    private settingsApigeeCredentials: string;
    private settingsApplicationInsightsKey: string;

    constructor(
        subscriptionId: string,
        resourceGroup: string,
        keyVaultUri: string,
        storageAccountId: string,
        storageAccountKey: string,
        statusTopicId: string,
        webHookUri: string,
        applicationInsightsKey: string,
    ) {
        this.settingsSubscriptionId = subscriptionId;
        this.settingsResourceGroup = resourceGroup;
        this.settingsKeyVaultUri = keyVaultUri;
        this.settingsStorageAccountId = storageAccountId;
        this.settingsStorageAccountKey = storageAccountKey;
        this.settingsStatusTopicId = statusTopicId;
        this.settingsWebHookUri = webHookUri;
        this.settingsApplicationInsightsKey = applicationInsightsKey;
    }
}

export { Settings };
