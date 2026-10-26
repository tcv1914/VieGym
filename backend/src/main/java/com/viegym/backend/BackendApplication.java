package com.viegym.backend;

import java.util.TimeZone;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class BackendApplication {

	public static void main(String[] args) {
		// Thời điểm lưu UTC (BR-G03). Không dùng múi giờ máy: Windows báo "Asia/Saigon",
		// PostgreSQL 17 từ chối tên này khi JDBC gửi TimeZone lúc kết nối.
		TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
		SpringApplication.run(BackendApplication.class, args);
	}

}
