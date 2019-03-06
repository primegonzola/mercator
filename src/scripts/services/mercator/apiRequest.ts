import {
    IApiRequest,
} from "./typings";

class ApiRequest implements IApiRequest {
    public path: string;
    public method: string;
    public body: any;
    constructor(method: string, path: string, body: any) {
        this.path = path;
        this.method = method;
        this.body = body;
    }
}

// export
export { ApiRequest };
