import { IApiResponse } from "./typings";

class ApiResponse implements IApiResponse {
    public body: any;
    public error: string;
    constructor(body?: any, error?: string) {
        this.body = body;
        this.error = error;
    }
}

// export
export { ApiResponse };
