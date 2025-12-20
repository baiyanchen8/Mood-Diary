import 'dart:math';
// 1. 重要：隱藏 flame/components 裡的 Vector2，只使用 forge2d 的
import 'package:flame/components.dart' hide Vector2;
import 'package:flame/game.dart' hide Vector2;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';
import '../../data/models/diary_entry.dart';

class MoodJarWidget extends StatelessWidget {
  final List<DiaryEntry> entries;

  const MoodJarWidget({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return GameWidget(game: MoodPhysicsGame(entries));
  }
}

class MoodPhysicsGame extends Forge2DGame {
  final List<DiaryEntry> entries;

  // 重力向下
  MoodPhysicsGame(this.entries) : super(gravity: Vector2(0, 60));

  @override
  Future<void> onLoad() async {
    // 建立邊界 (玻璃罐)
    // 註：新版 Flame 中 visibleWorldRect 依然可用，若報錯可改用 camera.viewfinder.visibleWorldRect
    final visibleRect = camera.visibleWorldRect;

    // 地板
    await world.add(
      Wall(
        Vector2(visibleRect.left, visibleRect.bottom),
        Vector2(visibleRect.right, visibleRect.bottom),
      ),
    );
    // 左牆
    await world.add(
      Wall(
        Vector2(visibleRect.left, visibleRect.top),
        Vector2(visibleRect.left, visibleRect.bottom),
      ),
    );
    // 右牆
    await world.add(
      Wall(
        Vector2(visibleRect.right, visibleRect.top),
        Vector2(visibleRect.right, visibleRect.bottom),
      ),
    );

    // 生成 Emoji
    final random = Random();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final xPos = (random.nextDouble() * 20) - 10;
      final yPos = -10.0 - (i * 2);

      await world.add(
        EmojiBody(
          emoji: entry.specificEmoji,
          position: Vector2(xPos, yPos),
          color: entry.mood.color,
        ),
      );
    }
  }
}

class Wall extends BodyComponent {
  final Vector2 start;
  final Vector2 end;

  Wall(this.start, this.end);

  @override
  Body createBody() {
    final shape = EdgeShape()..set(start, end);
    final fixtureDef = FixtureDef(shape, friction: 0.3);
    final bodyDef = BodyDef(type: BodyType.static);
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}

class EmojiBody extends BodyComponent {
  final String emoji;
  final Vector2 position;
  final Color color;

  EmojiBody({required this.emoji, required this.position, required this.color});

  @override
  Body createBody() {
    final shape = CircleShape()..radius = 2.5;

    final fixtureDef = FixtureDef(
      shape,
      restitution: 0.2, // 彈性
      density: 1.0, // 密度
      friction: 0.4, // 摩擦力
    );

    final bodyDef = BodyDef(
      position: position,
      type: BodyType.dynamic,
      angularDamping: 0.5,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(Canvas canvas) {
    // 2. 使用新版 API withValues (Flutter 3.22+)
    // 如果這裡報錯，請改回 withOpacity(0.8)
    final paint = Paint()..color = color.withValues(alpha: 0.8);
    canvas.drawCircle(Offset.zero, 2.5, paint);

    const textStyle = TextStyle(fontSize: 3.5, fontFamily: 'Roboto');
    final textSpan = TextSpan(text: emoji, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 1.5),
    );
  }
}
