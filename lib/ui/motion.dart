/**
 * @author Shakib
 * @since 29/10/26
 */
import 'package:flutter/widgets.dart';

Duration motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
