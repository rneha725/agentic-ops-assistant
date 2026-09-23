package org.prjct.controller;

import org.springframework.ai.chat.model.ChatModel;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController("/")
public class OllamaController {
    private final ChatModel chatModel;

    @Autowired
    OllamaController(final ChatModel chatModel) {
        this.chatModel = chatModel;
    }

    @GetMapping("/model/ping")
    public String modelPing() {
        System.out.printf("Pinging...");
        return this.chatModel.call("Tell me a joke");
    }
}
