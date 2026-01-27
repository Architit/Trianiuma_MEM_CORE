import pyautogui
import time

print("Тест через 3 секунды... Переключи раскладку на Английский и не трогай мышь.")
time.sleep(3)

print("1. Жму Win+R")
pyautogui.hotkey('win', 'r')
time.sleep(1)

print("2. Пишу calc.exe")
pyautogui.write('calc.exe')
time.sleep(0.5)

print("3. Жму Enter")
pyautogui.press('enter')

print("Готово.")
