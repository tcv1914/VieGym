-- Seed 32 bài tập ngày 6. Sinh bằng script, nội dung nguồn: docs/14-exercise-seed-catalog.md.
-- ID = uuid5(namespace cố định, code): giữ nguyên để giáo án ngày 7 tham chiếu.
-- Migration chỉ chạy một lần; sửa nội dung về sau bằng migration mới (UPDATE theo code), không xóa rồi tạo lại.
-- Media là key tương đối dưới /media/; backend ghép thành URL khi trả API.

INSERT INTO exercises (id, code, name, name_search, muscle_group, equipment, difficulty,
                       instructions, common_mistakes, thumbnail_url, media_type, media_url,
                       content_source, media_license)
VALUES
    ('485e3b1c-daf3-5a2c-9b07-7093d2b0987d', 'push-up', 'Hít đất (Push-up)', 'hit dat (push-up)', 'CHEST', 'NONE', 'BEGINNER', 'Vào tư thế plank cao, hai tay đặt rộng hơn vai một chút, hai chân khép.
Siết bụng, gập khuỷu tay hạ người xuống, giữ thân thẳng một đường từ đầu tới gót.
Dừng một nhịp khi ngực gần chạm sàn rồi duỗi tay đẩy người về vị trí ban đầu.
Lặp lại đủ số lần.', 'Võng hông hoặc chổng mông, thân không thẳng.
Khuỳnh khuỷu tay ngang vai.
Chỉ hạ nửa chừng, không đủ biên độ.', 'exercises/0662-I4hDWkc.jpg', 'GIF', 'exercises/0662-I4hDWkc.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('9d1a8e92-b49f-587a-979d-d93f640d445f', 'barbell-bench-press', 'Đẩy ngực với tạ đòn (Barbell Bench Press)', 'day nguc voi ta don (barbell bench press)', 'CHEST', 'BARBELL', 'INTERMEDIATE', 'Nằm ngửa trên ghế phẳng, hai bàn chân đặt chắc trên sàn, lưng và vai áp vào ghế.
Nắm thanh đòn sấp tay, rộng hơn vai một chút.
Nhấc đòn khỏi giá, giữ thẳng phía trên ngực với tay duỗi.
Hạ đòn chậm xuống giữa ngực, khuỷu tay hơi khép về phía thân.
Dừng một nhịp khi đòn chạm nhẹ ngực rồi đẩy lên tới khi tay duỗi.
Lặp lại đủ số lần; nên có người hỗ trợ khi tập nặng.', 'Nảy đòn khỏi ngực để lấy đà.
Nhấc mông khỏi ghế khi đẩy.
Hạ đòn quá cao về phía cổ hoặc không kiểm soát tốc độ.', 'exercises/0025-EIeI8Vf.jpg', 'GIF', 'exercises/0025-EIeI8Vf.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('2e641da1-1163-5176-b375-3171ee99f5f4', 'dumbbell-bench-press', 'Đẩy ngực với tạ đơn (Dumbbell Bench Press)', 'day nguc voi ta don (dumbbell bench press)', 'CHEST', 'DUMBBELL', 'BEGINNER', 'Nằm ngửa trên ghế phẳng, hai bàn chân đặt trên sàn, lưng áp vào ghế.
Mỗi tay cầm một tạ đơn, lòng bàn tay hướng về phía chân, tay duỗi phía trên ngực.
Hạ tạ chậm xuống hai bên ngực, khuỷu tay gập khoảng 90 độ.
Dừng một nhịp rồi đẩy tạ lên về vị trí ban đầu.
Lặp lại đủ số lần.', 'Hạ tạ quá nhanh, mất kiểm soát ở cuối biên độ.
Hai tạ đập vào nhau ở điểm trên cùng.
Khuỳnh khuỷu tay ngang vai gây áp lực lên khớp vai.', 'exercises/0289-SpYC0Kp.jpg', 'GIF', 'exercises/0289-SpYC0Kp.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('d117a44f-9f29-5ac6-9051-a0d22aecdeb9', 'incline-dumbbell-press', 'Đẩy ngực dốc lên với tạ đơn (Incline Dumbbell Press)', 'day nguc doc len voi ta don (incline dumbbell press)', 'CHEST', 'DUMBBELL', 'INTERMEDIATE', 'Chỉnh ghế dốc khoảng 30–45 độ.
Ngồi tựa lưng vào ghế, hai bàn chân đặt chắc trên sàn.
Cầm tạ đơn hai tay, đưa lên ngang vai, lòng bàn tay hướng về phía chân.
Đẩy tạ lên tới khi tay duỗi, sau đó hạ chậm về hai bên ngực trên.
Lặp lại đủ số lần.', 'Chỉnh ghế quá dốc khiến bài chuyển thành đẩy vai.
Ưỡn lưng, nhấc lưng khỏi ghế khi đẩy.
Hạ tạ không đủ sâu.', 'exercises/0314-ns0SIbU.jpg', 'GIF', 'exercises/0314-ns0SIbU.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('8519ef28-d71f-5825-a3c1-430b9b1db93f', 'lat-pulldown', 'Kéo xô xuống (Lat Pulldown)', 'keo xo xuong (lat pulldown)', 'BACK', 'CABLE', 'BEGINNER', 'Ngồi vào máy kéo cáp, chỉnh đệm đùi để giữ chân cố định.
Nắm thanh sấp tay, rộng hơn vai một chút.
Ngả người ra sau một chút, giữ ngực mở.
Kéo thanh xuống phía trên ngực, dẫn bằng khuỷu tay và siết hai bả vai.
Dừng một nhịp rồi thả thanh lên chậm về vị trí ban đầu.
Lặp lại đủ số lần.', 'Ngả người quá nhiều, dùng đà thân để kéo.
Kéo thanh ra sau gáy.
Thả thanh lên quá nhanh, không kiểm soát.', 'exercises/0150-eYnzaCm.jpg', 'GIF', 'exercises/0150-eYnzaCm.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('afb5c2c4-8da8-5bf8-8b55-db99c23b6c69', 'seated-cable-row', 'Kéo cáp ngồi (Seated Cable Row)', 'keo cap ngoi (seated cable row)', 'BACK', 'CABLE', 'BEGINNER', 'Ngồi vào máy, hai bàn chân đặt lên bệ, gối hơi chùng.
Nắm tay cầm, giữ lưng thẳng, vai thả lỏng.
Kéo tay cầm về phía bụng, siết hai bả vai vào nhau.
Dừng một nhịp rồi duỗi tay chậm về vị trí ban đầu.
Lặp lại đủ số lần.', 'Gù lưng hoặc ngả người ra sau để lấy đà.
Nhún vai lên khi kéo.
Chỉ kéo bằng tay, không siết bả vai.', 'exercises/0861-fUBheHs.jpg', 'GIF', 'exercises/0861-fUBheHs.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('e17c0842-6dd5-5969-a667-339f1a1ecaa7', 'one-arm-dumbbell-row', 'Chèo tạ đơn một tay (One-arm Dumbbell Row)', 'cheo ta don mot tay (one-arm dumbbell row)', 'BACK', 'DUMBBELL', 'BEGINNER', 'Đứng hai chân rộng bằng vai, một tay cầm tạ đơn, lòng bàn tay hướng vào thân.
Hơi chùng gối, gập người từ hông, lưng thẳng và siết bụng.
Để tạ buông thẳng xuống sàn, tay duỗi.
Kéo tạ lên về phía hông, khuỷu tay sát thân, siết bả vai.
Dừng một nhịp rồi hạ chậm; đủ số lần thì đổi tay.', 'Xoay thân để kéo tạ lên.
Cong lưng khi gập người.
Kéo tạ bằng cẳng tay thay vì dẫn bằng khuỷu.', 'exercises/0292-C0MA9bC.jpg', 'GIF', 'exercises/0292-C0MA9bC.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('7b7c3634-e2bf-5910-b060-1d90bc066b92', 'pull-up', 'Hít xà đơn (Pull-up)', 'hit xa don (pull-up)', 'BACK', 'OTHER', 'ADVANCED', 'Treo người trên xà, nắm sấp tay, tay duỗi thẳng.
Siết bụng và kéo hai bả vai xuống.
Gập khuỷu tay kéo người lên tới khi cằm qua xà.
Dừng một nhịp rồi hạ người chậm tới khi tay duỗi.
Lặp lại đủ số lần.', 'Đu người, đá chân để lấy đà.
Không duỗi tay hết ở dưới, biên độ ngắn.
Thả rơi người xuống thay vì hạ chậm.', 'exercises/0652-lBDjFxJ.jpg', 'GIF', 'exercises/0652-lBDjFxJ.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('a7863b4e-83d6-54e3-b51f-fa01efbef02f', 'barbell-deadlift', 'Deadlift với tạ đòn (Barbell Deadlift)', 'deadlift voi ta don (barbell deadlift)', 'FULL_BODY', 'BARBELL', 'ADVANCED', 'Đứng hai chân rộng bằng hông, thanh đòn sát ống chân.
Gập hông và gối, nắm đòn sấp tay ngay ngoài hai chân.
Giữ lưng thẳng, ngực mở, đạp gót để kéo đòn lên, duỗi hông và gối cùng lúc.
Khi đứng thẳng, siết mông và bụng.
Hạ đòn xuống sàn bằng cách gập hông rồi gối, lưng vẫn thẳng.
Lặp lại đủ số lần.', 'Cong lưng khi kéo hoặc khi hạ.
Để thanh đòn xa người.
Ngả người ra sau quá mức ở điểm trên cùng.', 'exercises/0032-ila4NZS.jpg', 'GIF', 'exercises/0032-ila4NZS.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('58ce16c0-55c0-54ef-bb98-e8c15897ebf6', 'dumbbell-shoulder-press', 'Đẩy vai với tạ đơn (Dumbbell Shoulder Press)', 'day vai voi ta don (dumbbell shoulder press)', 'SHOULDERS', 'DUMBBELL', 'BEGINNER', 'Ngồi trên ghế có tựa lưng, mỗi tay cầm một tạ đơn đặt trên đùi.
Đưa tạ lên ngang vai, lòng bàn tay hướng ra trước.
Đẩy tạ lên tới khi tay duỗi phía trên đầu.
Dừng một nhịp rồi hạ chậm về ngang vai.
Lặp lại đủ số lần.', 'Ưỡn lưng quá mức khi đẩy.
Hạ tạ không tới ngang vai.
Khóa cứng khuỷu tay mạnh ở điểm trên cùng.', 'exercises/0405-znQUdHY.jpg', 'GIF', 'exercises/0405-znQUdHY.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('73fb162e-6461-5028-84ab-2b94c6129126', 'lateral-raise', 'Nâng tạ đơn sang ngang (Lateral Raise)', 'nang ta don sang ngang (lateral raise)', 'SHOULDERS', 'DUMBBELL', 'BEGINNER', 'Đứng hai chân rộng bằng vai, mỗi tay cầm một tạ đơn, lòng bàn tay hướng vào thân.
Giữ lưng thẳng và siết bụng.
Nâng hai tay sang ngang tới khi song song mặt sàn, khuỷu hơi chùng.
Dừng một nhịp rồi hạ chậm về vị trí ban đầu.
Lặp lại đủ số lần.', 'Dùng tạ quá nặng rồi vung người lấy đà.
Nhún vai lên tai khi nâng.
Nâng tay cao quá vai.', 'exercises/0334-DsgkuIt.jpg', 'GIF', 'exercises/0334-DsgkuIt.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('67b3cbd1-ebdc-5264-9697-d67592ed788d', 'reverse-fly', 'Bay ngược với tạ đơn (Reverse Fly)', 'bay nguoc voi ta don (reverse fly)', 'SHOULDERS', 'DUMBBELL', 'INTERMEDIATE', 'Đứng hai chân rộng bằng vai, mỗi tay cầm một tạ đơn.
Hơi chùng gối, gập người từ hông, lưng thẳng.
Để hai tay buông xuống phía trước, lòng bàn tay hướng vào nhau.
Giữ khuỷu hơi chùng, mở hai tay sang ngang tới khi gần song song mặt sàn.
Dừng một nhịp rồi hạ chậm; lặp lại đủ số lần.', 'Cong lưng khi gập người.
Gập duỗi khuỷu tay, biến bài thành kéo tạ.
Dùng đà thân để vung tạ lên.', 'exercises/0383-EAs3xL9.jpg', 'GIF', 'exercises/0383-EAs3xL9.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('924f4773-4fbb-531a-bce3-66f663b5a1d3', 'dumbbell-curl', 'Cuốn tạ đơn (Dumbbell Curl)', 'cuon ta don (dumbbell curl)', 'ARMS', 'DUMBBELL', 'BEGINNER', 'Đứng thẳng, mỗi tay cầm một tạ đơn, lòng bàn tay hướng ra trước, tay duỗi.
Giữ bắp tay trên cố định, thở ra và cuốn tạ lên.
Cuốn tới khi tạ ngang vai, siết cơ tay trước một nhịp.
Hít vào và hạ tạ chậm về vị trí ban đầu.
Lặp lại đủ số lần.', 'Đưa khuỷu tay ra trước khi cuốn.
Vung người để lấy đà.
Hạ tạ quá nhanh, không duỗi hết tay.', 'exercises/0294-NbVPDMW.jpg', 'GIF', 'exercises/0294-NbVPDMW.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('65c9defd-7704-5bba-8d9f-859e36860760', 'hammer-curl', 'Cuốn tạ búa (Hammer Curl)', 'cuon ta bua (hammer curl)', 'ARMS', 'DUMBBELL', 'BEGINNER', 'Đứng thẳng, mỗi tay cầm một tạ đơn, lòng bàn tay hướng vào thân.
Giữ khuỷu tay sát thân và bắp tay trên cố định.
Thở ra và cuốn tạ lên, giữ nguyên hướng lòng bàn tay.
Dừng một nhịp ở trên rồi hít vào, hạ chậm.
Lặp lại đủ số lần.', 'Xoay cổ tay trong khi cuốn.
Khuỷu tay rời khỏi thân.
Vung người để lấy đà.', 'exercises/0313-slDvUAU.jpg', 'GIF', 'exercises/0313-slDvUAU.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('ea9e9d8b-43c0-58b5-9700-2fce178ac481', 'cable-curl', 'Cuốn tay trước với cáp (Cable Curl)', 'cuon tay truoc voi cap (cable curl)', 'ARMS', 'CABLE', 'BEGINNER', 'Đứng đối diện máy cáp đặt ròng rọc thấp, hai chân rộng bằng vai.
Nắm tay cầm ngửa tay.
Giữ khuỷu tay sát thân, bắp tay trên cố định.
Thở ra và cuốn tay cầm lên về phía vai.
Dừng một nhịp rồi hít vào, hạ chậm; lặp lại đủ số lần.', 'Ngả người ra sau để kéo.
Khuỷu tay trượt ra trước.
Thả tay cầm về quá nhanh.', 'exercises/0868-G08RZcQ.jpg', 'GIF', 'exercises/0868-G08RZcQ.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('3e82a1f0-a877-598a-b0aa-4fc764fffa1f', 'cable-pushdown', 'Đẩy cáp xuống (Cable Pushdown)', 'day cap xuong (cable pushdown)', 'ARMS', 'CABLE', 'BEGINNER', 'Gắn thanh thẳng vào ròng rọc cao.
Đứng đối diện máy, hai chân rộng bằng vai, gối hơi chùng.
Nắm thanh sấp tay, hai tay rộng bằng vai.
Giữ khuỷu tay sát thân, thở ra và đẩy thanh xuống tới khi tay duỗi.
Dừng một nhịp rồi hít vào, đưa thanh lên chậm; lặp lại đủ số lần.', 'Khuỷu tay rời khỏi thân.
Đè người lên thanh để đẩy.
Để thanh bật lên quá cao, mất căng cơ.', 'exercises/0201-3ZflifB.jpg', 'GIF', 'exercises/0201-3ZflifB.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('a3baaa6c-8686-5d52-9261-3b515bcd6243', 'overhead-dumbbell-extension', 'Duỗi tay sau qua đầu với tạ đơn (Overhead Dumbbell Extension)', 'duoi tay sau qua dau voi ta don (overhead dumbbell extension)', 'ARMS', 'DUMBBELL', 'BEGINNER', 'Ngồi trên ghế, lưng thẳng, hai bàn chân đặt trên sàn.
Hai tay giữ một tạ đơn, duỗi thẳng lên trên đầu.
Gập khuỷu tay, hạ tạ ra sau đầu, bắp tay trên giữ sát hai tai.
Dừng một nhịp rồi duỗi tay đưa tạ lên vị trí ban đầu.
Lặp lại đủ số lần.', 'Khuỷu tay mở rộng sang hai bên.
Ưỡn lưng khi đẩy tạ lên.
Hạ tạ quá nhanh ra sau đầu.', 'exercises/2188-kont8Ut.jpg', 'GIF', 'exercises/2188-kont8Ut.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('584cb1f9-d269-5ccb-afbe-f1712ce77c17', 'close-grip-push-up', 'Hít đất tay hẹp (Close-grip Push-up)', 'hit dat tay hep (close-grip push-up)', 'ARMS', 'NONE', 'INTERMEDIATE', 'Vào tư thế plank cao, hai tay đặt hẹp ngay dưới vai.
Siết bụng, hạ người xuống, giữ khuỷu tay sát thân.
Đẩy qua lòng bàn tay để duỗi tay về vị trí ban đầu.
Lặp lại đủ số lần.', 'Khuỷu tay mở sang ngang.
Võng hông.
Đặt tay quá sát làm đau cổ tay.', 'exercises/0259-x6KpKpq.jpg', 'GIF', 'exercises/0259-x6KpKpq.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('a3b59e94-1269-51f1-bf8c-c6cdf9ecae8d', 'bodyweight-squat', 'Squat không tạ (Bodyweight Squat)', 'squat khong ta (bodyweight squat)', 'LEGS', 'NONE', 'BEGINNER', 'Đứng hai chân rộng bằng vai, mũi chân hơi mở ra ngoài.
Giữ ngực mở, đẩy hông ra sau và gập gối như ngồi xuống ghế.
Hạ người tới khi đùi gần song song mặt sàn hoặc thấp nhất có thể mà lưng vẫn thẳng.
Đạp gót để đứng lên.
Lặp lại đủ số lần.', 'Gối chụm vào trong.
Nhấc gót khỏi sàn.
Cúi gập người quá nhiều về phía trước.', NULL, NULL, NULL, 'VieGym biên soạn; không có bài tương ứng trong exercises-dataset', NULL),
    ('2e724aa8-9b90-521e-afcd-f91c25632d60', 'goblet-squat', 'Squat ôm tạ đơn (Goblet Squat)', 'squat om ta don (goblet squat)', 'LEGS', 'DUMBBELL', 'BEGINNER', 'Đứng hai chân rộng bằng vai, hai tay ôm một tạ đơn dựng đứng trước ngực.
Giữ ngực mở, siết bụng, đẩy hông ra sau và gập gối để hạ người.
Hạ tới khi đùi song song mặt sàn hoặc thấp nhất có thể một cách thoải mái.
Dừng một nhịp rồi đạp gót đứng lên.
Lặp lại đủ số lần.', 'Để tạ rời xa ngực.
Gối chụm vào trong.
Cong lưng ở cuối biên độ.', 'exercises/1760-yn8yg1r.jpg', 'GIF', 'exercises/1760-yn8yg1r.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('7328822c-f14a-5faf-9617-bd487fa14748', 'barbell-back-squat', 'Squat với tạ đòn (Barbell Back Squat)', 'squat voi ta don (barbell back squat)', 'LEGS', 'BARBELL', 'INTERMEDIATE', 'Đặt thanh đòn trên lưng trên (cơ cầu vai), hai chân rộng bằng vai, mũi chân hơi mở.
Siết bụng, giữ ngực mở.
Gập gối và hông, đẩy hông ra sau và xuống như ngồi vào ghế.
Hạ tới khi đùi song song mặt sàn hoặc thấp hơn một chút; gối cùng hướng mũi chân.
Đạp gót để đứng lên, duỗi hông và gối.
Lặp lại đủ số lần; tập nặng nên dùng giá squat có thanh chặn an toàn.', 'Gối chụm vào trong khi đứng lên.
Nhấc gót, dồn trọng lượng lên mũi chân.
Cong lưng dưới ở điểm thấp nhất.', 'exercises/0043-qXTaZnJ.jpg', 'GIF', 'exercises/0043-qXTaZnJ.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('ad2b193d-2d0b-5ff6-aa17-4958e16a2d00', 'leg-press', 'Đạp đùi máy 45° (Leg Press)', 'dap dui may 45° (leg press)', 'LEGS', 'MACHINE', 'BEGINNER', 'Chỉnh ghế và bàn đạp tới vị trí thoải mái.
Ngồi tựa lưng vào đệm, hai chân đặt rộng bằng vai trên bàn đạp.
Nắm tay cầm hai bên ghế để giữ người.
Duỗi chân đẩy bàn đạp ra, gót luôn áp vào bàn đạp.
Dừng khi chân gần duỗi hết, không khóa gối, rồi gập gối hạ bàn đạp chậm.
Lặp lại đủ số lần.', 'Khóa cứng gối ở điểm trên cùng.
Hạ quá sâu làm hông và lưng dưới nhấc khỏi đệm.
Đặt chân quá thấp khiến gót nhấc lên.', 'exercises/0739-10Z2DXU.jpg', 'GIF', 'exercises/0739-10Z2DXU.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('297af78d-6c6c-5074-96c7-674cac5c0a5b', 'lying-leg-curl', 'Cuốn đùi sau nằm (Lying Leg Curl)', 'cuon dui sau nam (lying leg curl)', 'LEGS', 'MACHINE', 'BEGINNER', 'Chỉnh máy vừa người và chọn mức tạ.
Nằm sấp, chân duỗi, gót đặt dưới đệm cuốn.
Nắm tay cầm để giữ người.
Giữ thân trên cố định, thở ra và cuốn chân lên hết mức có thể mà hông không nhấc khỏi đệm.
Dừng một nhịp rồi hít vào, hạ chậm; lặp lại đủ số lần.', 'Nhấc hông khỏi đệm để cuốn.
Thả đệm xuống nhanh.
Biên độ quá ngắn.', 'exercises/0586-17lJ1kr.jpg', 'GIF', 'exercises/0586-17lJ1kr.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('69222925-9c2d-57f9-9a35-0fd3b8050d65', 'calf-raise', 'Nhón bắp chân (Calf Raise)', 'nhon bap chan (calf raise)', 'LEGS', 'NONE', 'BEGINNER', 'Đứng hai chân rộng bằng vai, mũi chân hướng thẳng.
Đặt tay lên tường hoặc vật chắc chắn để giữ thăng bằng.
Nhón gót lên chậm, dồn trọng lượng lên phần trước bàn chân.
Dừng một nhịp ở trên rồi hạ gót chậm.
Lặp lại đủ số lần.', 'Nhún nhanh, không dừng ở trên.
Biên độ ngắn.
Đổ trọng lượng ra mép ngoài bàn chân.', 'exercises/1373-bJYHBIN.jpg', 'GIF', 'exercises/1373-bJYHBIN.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('2fc06781-fb7a-5e9d-be60-a1043bd560cc', 'dumbbell-lunge', 'Chùng chân với tạ đơn (Dumbbell Lunge)', 'chung chan voi ta don (dumbbell lunge)', 'LEGS', 'DUMBBELL', 'BEGINNER', 'Đứng hai chân rộng bằng vai, mỗi tay cầm một tạ đơn.
Bước chân phải lên trước, hạ người vào tư thế chùng chân.
Giữ lưng thẳng và ngực mở khi hạ người.
Đạp gót chân phải để về vị trí ban đầu.
Đổi sang chân trái; luân phiên đủ số lần.', 'Gối trước đổ vào trong.
Bước quá ngắn làm gối trước vượt xa mũi chân.
Đổ người về phía trước.', 'exercises/0336-RRWFUcw.jpg', 'GIF', 'exercises/0336-RRWFUcw.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('49259ead-cbbd-5c3a-b096-53a543a88c49', 'romanian-deadlift', 'Romanian Deadlift với tạ đòn (RDL)', 'romanian deadlift voi ta don (rdl)', 'GLUTES', 'BARBELL', 'INTERMEDIATE', 'Đứng hai chân rộng bằng hông, cầm đòn sấp tay rộng hơn vai một chút.
Gối hơi chùng, gập người từ hông, lưng thẳng.
Hạ đòn dọc theo đùi và ống chân, giữ đòn sát người.
Khi thấy căng ở đùi sau, đẩy hông ra trước để đứng thẳng.
Siết mông ở điểm trên cùng; lặp lại đủ số lần.', 'Cong lưng khi hạ đòn.
Gập gối nhiều biến thành squat.
Để đòn xa người.', 'exercises/0085-wQ2c4XD.jpg', 'GIF', 'exercises/0085-wQ2c4XD.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('8601567e-e57b-5e7d-8b53-60ec81901628', 'glute-bridge', 'Cầu mông (Glute Bridge)', 'cau mong (glute bridge)', 'GLUTES', 'NONE', 'BEGINNER', 'Nằm ngửa, gập gối, hai bàn chân đặt trên sàn.
Hai tay đặt dọc thân, lòng bàn tay úp.
Siết mông và bụng, nâng hông lên tới khi gối, hông, vai thành một đường thẳng.
Dừng một nhịp, siết mông.
Hạ hông chậm; lặp lại đủ số lần.', 'Ưỡn lưng dưới thay vì dùng mông.
Đẩy bằng mũi chân, nhấc gót.
Hạ hông quá nhanh.', 'exercises/3013-u0cNiij.jpg', 'GIF', 'exercises/3013-u0cNiij.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('7ec3e72f-e9f4-59ed-a8b8-19437a63e57d', 'plank', 'Plank', 'plank', 'CORE', 'NONE', 'BEGINNER', 'Chống hai cẳng tay xuống sàn, khuỷu tay ngay dưới vai.
Duỗi hai chân ra sau, chống bằng mũi chân.
Siết bụng và mông, giữ thân thẳng một đường từ đầu tới gót.
Giữ tư thế trong thời gian đã định, thở đều.', 'Võng hông.
Chổng mông quá cao.
Nín thở.', NULL, NULL, NULL, 'VieGym biên soạn; không có bài tương ứng trong exercises-dataset', NULL),
    ('4efb03fe-2cb8-5e67-8764-437eb6e44852', 'dead-bug', 'Dead Bug', 'dead bug', 'CORE', 'NONE', 'BEGINNER', 'Nằm ngửa, hai tay duỗi thẳng hướng lên trần.
Gập hông và gối 90 độ, nhấc chân khỏi sàn.
Siết bụng, ép lưng dưới xuống sàn.
Hạ chậm tay phải và chân trái xuống gần sàn.
Về vị trí ban đầu rồi đổi bên; luân phiên đủ số lần.', 'Lưng dưới nhấc khỏi sàn.
Làm quá nhanh, mất kiểm soát.
Nín thở.', 'exercises/0276-iny3m5y.jpg', 'GIF', 'exercises/0276-iny3m5y.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('9881f581-3f75-5b96-907e-e8b2637371d3', 'bird-dog', 'Bird Dog', 'bird dog', 'CORE', 'NONE', 'BEGINNER', 'Quỳ bốn điểm, tay ngay dưới vai, gối ngay dưới hông.
Siết bụng, giữ lưng phẳng.
Duỗi tay phải ra trước và chân trái ra sau tới khi song song mặt sàn.
Dừng một nhịp rồi thu về; đổi bên và luân phiên đủ số lần.', 'Xoay hoặc nghiêng hông khi duỗi chân.
Ưỡn lưng, nâng chân quá cao.
Làm quá nhanh.', NULL, NULL, NULL, 'VieGym biên soạn; không có bài tương ứng trong exercises-dataset', NULL),
    ('e1e3ba90-c04f-5c07-8125-d6ada70b47e6', 'mountain-climber', 'Leo núi tại chỗ (Mountain Climber)', 'leo nui tai cho (mountain climber)', 'CARDIO', 'NONE', 'BEGINNER', 'Vào tư thế plank cao, tay ngay dưới vai, thân thẳng.
Siết bụng, kéo gối phải về phía ngực rồi đổi nhanh sang gối trái.
Luân phiên hai chân như chạy, giữ hông thấp.
Giữ nhịp đều và thở đều trong suốt bài.', 'Chổng mông cao.
Vai lùi ra sau cổ tay.
Nín thở.', 'exercises/0630-RJgzwny.jpg', 'GIF', 'exercises/0630-RJgzwny.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT'),
    ('6db17e08-5c33-5352-ab31-ac4e2845762b', 'burpee', 'Burpee', 'burpee', 'CARDIO', 'NONE', 'INTERMEDIATE', 'Đứng hai chân rộng bằng vai.
Ngồi xuống, đặt hai tay lên sàn trước mặt.
Bật hai chân ra sau vào tư thế hít đất và thực hiện một lần hít đất.
Bật chân về tư thế ngồi.
Bật nhảy lên, vươn tay qua đầu, tiếp đất nhẹ rồi vào lần tiếp theo.', 'Võng hông khi ở tư thế hít đất.
Tiếp đất nặng, gối khóa cứng.
Làm nhanh nhưng sai tư thế.', 'exercises/1160-dK9394r.jpg', 'GIF', 'exercises/1160-dK9394r.gif', 'Hướng dẫn biên soạn tiếng Việt từ exercises-dataset (MIT, github.com/hasaneyldrm/exercises-dataset); lỗi thường gặp do VieGym biên soạn', '© Gym visual — https://gymvisual.com/. Ảnh/GIF 180×180 phân phối lại theo NOTICE.md của exercises-dataset; không thuộc giấy phép MIT');
