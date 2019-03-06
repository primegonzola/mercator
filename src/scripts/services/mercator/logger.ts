/* tslint:disable:no-bitwise */
import * as appInsights from "applicationinsights";
import * as util from "util";

import { Settings } from "./settings";
import { IContext, ILogger, LoggerOptions } from "./typings";
import { Utils } from "./utils";

enum LogTypeOptions {
    None = 0,
    Trace = 1,
    Info = 2,
    Warning = 4,
    Error = 8,
    All = 15,
}

// simple logger stub, needs to be upgraded to log4js
class Logger implements ILogger {
    public static theContext = null;

    public static enter<T>(caller: string, fn: () => T): T {
        // track entering
        Logger.trackTrace("Entering " + caller);
        // our result
        let result;
        try {
            // call method
            result = fn();
        } catch (reason) {
            // track
            Logger.trackException(reason);
            // track leaving
            Logger.trackTrace("Leaving " + caller);
            // rethrow
            throw reason;
        }
        // track leaving
        Logger.trackTrace("Leaving " + caller);
        // all done
        return result;
    }

    public static async enterAsync<T>(caller: string, fn: () => Promise<T>): Promise<T> {
        // track entering
        Logger.trackTrace("Entering " + caller);
        // our result
        let result;
        try {
            // call method
            result = await fn();
        } catch (reason) {
            // track
            Logger.trackException(reason);
            // call failure
            result = Promise.reject(reason);
        }
        // track leaving
        Logger.trackTrace("Leaving " + caller);
        // all done
        return Promise.resolve(result);
    }

    public static createInstance(context: IContext, options: LoggerOptions): Promise<ILogger> {
        return Logger.enterAsync<ILogger>("Logger.trace", async () => {
            // get settings
            const settings = await Settings.get();
            // set environment options
            options = options || {};
            // check if enabled
            if (Settings.isEnabled) {
                options.applicationInsightsKey = options.applicationInsightsKey || settings.applicationInsightsKey;
            }
            // nothing to do so create our logger and done
            return new Logger(context, options);
        });
    }
    public static log(data: any) {
        if (Logger.theContext !== null) {
            Logger.theContext.log(data);
        }
    }
    private static insightsClient;
    private static trackTrace(msg: string): void {
        const client = Logger.insightsClient || appInsights.defaultClient;
        if (client !== undefined && Utils.isDebug()) {
            client.trackTrace({ message: msg });
        }
    }

    private static trackException(error: Error): void {
        const client = Logger.insightsClient || appInsights.defaultClient;
        if (client !== undefined) {
            client.trackException({ exception: error });
        }
    }

    private static trackEvent(name: string, properties: object): void {
        const client = Logger.insightsClient || appInsights.defaultClient;
        if (client !== undefined) {
            client.trackEvent({ name, properties });
        }
    }

    private context: any;
    private options: LoggerOptions;
    constructor(context: IContext, options: LoggerOptions) {
        Logger.enter("Logger.constructor", () => {
            Logger.theContext = context;
            this.context = context;
            this.options = options || {};
            this.options.category = this.options.category || "unknown-category";
            this.options.filter = this.options.filter ||
                parseInt(Utils.getVariable("MERCATOR_LOG_LEVEL", LogTypeOptions.All), 10);
            this.options.custom = this.options.custom || null;
            // see if our client needs initialization
            if (Logger.insightsClient === undefined &&
                options.applicationInsightsKey !== undefined &&
                options.applicationInsightsKey !== null &&
                options.applicationInsightsKey !== "") {
                // create our client
                appInsights.setup(options.applicationInsightsKey)
                    .setAutoCollectRequests(true)
                    .setAutoCollectPerformance(true)
                    .setAutoCollectExceptions(true)
                    .setAutoCollectConsole(true)
                    .setAutoCollectDependencies(true)
                    .setUseDiskRetryCaching(true)
                    .setAutoDependencyCorrelation(false)
                    .start();
                // init client
                Logger.insightsClient = appInsights.defaultClient;
            }
        });
    }

    public trace(msg: string) {
        Logger.enter("Logger.trace", () => {
            if ((this.options.filter & LogTypeOptions.Trace) !== 0) {
                this.emitEvent(LogTypeOptions.Trace, msg, null);
            }
        });
    }
    public info(msg: string) {
        Logger.enter("Logger.info", () => {
            if ((this.options.filter & LogTypeOptions.Info) !== 0) {
                this.emitEvent(LogTypeOptions.Info, msg, null);
            }
        });
    }
    public warn(msg: string, error: Error) {
        Logger.enter("Logger.warn", () => {
            if ((this.options.filter & LogTypeOptions.Warning) !== 0) {
                this.emitEvent(LogTypeOptions.Warning, msg, error);
            }
        });
    }
    public error(msg: string, error: Error) {
        Logger.enter("Logger.error", () => {
            if ((this.options.filter & LogTypeOptions.Error) !== 0) {
                this.emitEvent(LogTypeOptions.Error, msg, error);
            }
        });
    }

    public typeToString(type: LogTypeOptions): string {
        return Logger.enter<string>("Logger.typeToString", () => {
            switch (type) {
                case LogTypeOptions.Trace:
                    return "trace";
                case LogTypeOptions.Info:
                    return "info";
                case LogTypeOptions.Warning:
                    return "warning";
                case LogTypeOptions.Error:
                    return "error";
                default:
                    return "Unknown";
            }
        });
    }

    public internalTrace(type: LogTypeOptions, msg: string, error: Error) {
        Logger.enter("Logger.internalTrace", () => {
            const text = (error !== undefined && error !== null) ? error.message : "none";
            this.context.log.warn(util.format("%s: %s error: %s", this.typeToString(type), msg, text));
            Logger.trackEvent("internal-trace", { message: msg });
        });
    }

    public nativeEvent(type: LogTypeOptions, msg: string, error: Error) {
        Logger.enter("Logger.nativeEvent", () => {
            const text = (error !== undefined && error !== null) ? error.message : "none";
            const nmsg = (text === "none") ?
                util.format("%s: %s", this.typeToString(type), msg) :
                util.format("%s: %s error: %s", this.typeToString(type), msg, text);
            switch (type) {
                case LogTypeOptions.Trace:
                    this.context.log.info(nmsg);
                    break;
                case LogTypeOptions.Info:
                    this.context.log.info(nmsg);
                    break;
                case LogTypeOptions.Warning:
                    this.context.log.warn(nmsg);
                    break;
                case LogTypeOptions.Error:
                    this.context.log.error(nmsg);
                    break;
            }
        });
    }

    public emitEvent(type: LogTypeOptions, msg: string, error: Error) {
        Logger.enter("Logger.emitEvent", () => {
            try {
                // send native event
                this.nativeEvent(type, msg, error);
            } catch (err) {
                Logger.trackException(err);
                this.internalTrace(LogTypeOptions.Error, "native-emitEvent", err);
            }
            try {
                // send app event
                this.appEvent(type, msg, error);
            } catch (err) {
                Logger.trackException(err);
                this.internalTrace(LogTypeOptions.Error, "native-emitEvent", err);
            }
        });
    }

    public appEvent(type: LogTypeOptions, msg: string, error: any) {
        Logger.enter("Logger.appEvent", () => {
            Logger.trackEvent(this.typeToString(type), {
                error: (error !== undefined && error != null && error.message !== undefined) ? error.message : "",
                level: this.typeToString(type),
                message: msg,
                source: this.options.category,
                statusCode: (error !== undefined && error != null &&
                    error.statusCode !== undefined) ? error.statusCode : 0,
                when: new Date().toUTCString(),
            });
        });
    }
}

// export
export { Logger };
