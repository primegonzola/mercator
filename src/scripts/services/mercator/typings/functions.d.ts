export interface IContext {
    invocationId: string;
    bindingData: any;
    bindings: any;
    log(text: any): any;
    done(err?: any, output?: {
        [s: string]: any;
    }): void;
}

export interface IFunctionRequest {
    originalUrl: string;
    method: string;
    query: {
        [s: string]: string;
    };
    headers: {
        [s: string]: string;
    };
    body: any;
    rawbody: any;
}

export interface IFunctionTimer {
    isPastDue: boolean;
    last: Date;
    next: Date;
}

export interface IFunctionEvent {
    topic: string;
    subject: string,
    eventType: string,
    data: any;
}

export interface IFunctionResponse {
    body?: any;
    status?: number;
    headers?: {
        "content-type"?: string;
        "content-length"?: number;
        "content-disposition"?: string;
        "content-encoding"?: string;
        "content-language"?: string;
        "content-range"?: string;
        "content-location"?: string;
        "content-md5"?: Buffer;
        "expires"?: Date;
        "last-modified"?: Date;
        [s: string]: any;
    };
}