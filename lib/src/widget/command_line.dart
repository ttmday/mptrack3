import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mptrack3/src/service/audio_manager.dart';

import 'package:mptrack3/src/constants/color.dart';
import 'package:mptrack3/src/constants/design.dart';

class CommandLine extends StatelessWidget {
  const CommandLine({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RichText(
                  text: TextSpan(
                children: [
                  const TextSpan(text: "mptrack3:"),
                  TextSpan(
                    text: "~",
                    style: AppDesign.textTheme(context)
                        .bodyMedium!
                        .copyWith(fontSize: 15.0, color: AppColors.primary),
                  ),
                  TextSpan(
                    text: "\$",
                    style: AppDesign.textTheme(context)
                        .bodyMedium!
                        .copyWith(fontSize: 15.0, color: AppColors.text),
                  )
                ],
                style: AppDesign.textTheme(context).bodyMedium!.copyWith(
                    fontSize: 15.0,
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700),
              )),
              const SizedBox(
                width: AppDesign.padding / 2,
              ),
              const Expanded(child: SearchTextField())
            ],
          ),
        ],
      ),
    );
  }
}

class SearchTextField extends StatefulWidget {
  const SearchTextField({
    super.key,
  });

  @override
  State<SearchTextField> createState() => _SearchTextFieldState();
}

class _SearchTextFieldState extends State<SearchTextField> {
  final TextEditingController _controller = TextEditingController();
  late final AudioManager _audioManager;
  Timer? debounce;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioManager = context.read<AudioManager>();
    });

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      cursorWidth: 12.0,
      decoration: const InputDecoration(
          hintText: "Escribe aquí el nombre de una canción.",
          hintMaxLines: 1,
          hintStyle: TextStyle(
            color: AppColors.foreground,
            fontSize: 12.5,
            fontWeight: FontWeight.w300,
            overflow: TextOverflow.ellipsis,
          ),
          border: InputBorder.none),
      onChanged: onSearchSong,
    );
  }

  void onSearchSong(String search) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () {
      _audioManager.playFromQuery(search);
    });
  }
}
