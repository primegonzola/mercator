package coredb;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ApiController {
    
    @RequestMapping("/version")
    public String version() {
        return "version: v1.0.0";
    }

    @RequestMapping("/health")
    public String health() {
        return "status: OK";
    }
}
